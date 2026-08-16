package main

import (
	"context"
	"errors"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/evosynx/anime-tracker/internal/anilist"
	"github.com/evosynx/anime-tracker/internal/hub"
	"github.com/evosynx/anime-tracker/internal/poller"
	"github.com/evosynx/anime-tracker/internal/server"
	"github.com/evosynx/anime-tracker/internal/store"
)

func main() {
	var (
		addr         = flag.String("addr", ":8080", "HTTP listen address")
		dbPath       = flag.String("db", "data/tracker.db", "bbolt database path")
		pollInterval = flag.Duration("poll", 5*time.Minute, "realtime poll interval")
		includeAdult = flag.Bool("adult", false, "include adult entries in feeds")
		seasonOffset = flag.Int("season-offset", 0, "browse offset from current season (-1..1)")
	)
	flag.Parse()

	if err := os.MkdirAll(filepath.Dir(*dbPath), 0o755); err != nil {
		log.Fatalf("mkdir db dir: %v", err)
	}

	st, err := store.Open(*dbPath)
	if err != nil {
		log.Fatalf("open store: %v", err)
	}
	defer st.Close()

	client := anilist.NewClient()
	h := hub.NewHub()

	pcfg := poller.DefaultConfig()
	pcfg.Interval = *pollInterval
	pcfg.IncludeAdult = *includeAdult

	p := poller.New(client, st, h, pcfg)

	scfg := server.DefaultConfig()
	scfg.IncludeAdult = *includeAdult
	scfg.SeasonOffset = *seasonOffset

	srv := server.New(client, st, h, p, scfg)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go p.Run(ctx)

	httpSrv := &http.Server{
		Addr:              *addr,
		Handler:           srv.Handler(),
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("anime-tracker listening on http://%s (adult=%v)", *addr, *includeAdult)
		if err := httpSrv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("http server: %v", err)
		}
	}()

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt, syscall.SIGTERM)
	<-sig

	log.Println("shutting down...")
	cancel()
	shutdownCtx, done := context.WithTimeout(context.Background(), 10*time.Second)
	defer done()
	_ = httpSrv.Shutdown(shutdownCtx)
}

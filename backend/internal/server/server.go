package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/evosynx/anime-tracker/internal/anilist"
	"github.com/evosynx/anime-tracker/internal/hub"
	"github.com/evosynx/anime-tracker/internal/poller"
	"github.com/evosynx/anime-tracker/internal/store"
)

// Server wires handlers and services together.
type Server struct {
	client *anilist.Client
	store  *store.Store
	hub    *hub.Hub
	poller *poller.Poller
	cfg    Config
}

// Config holds server-level options.
type Config struct {
	IncludeAdult bool
	SeasonOffset int
}

// DefaultConfig returns server defaults.
func DefaultConfig() Config {
	return Config{IncludeAdult: false, SeasonOffset: 0}
}

// New constructs a Server.
func New(client *anilist.Client, st *store.Store, h *hub.Hub, p *poller.Poller, cfg Config) *Server {
	return &Server{client: client, store: st, hub: h, poller: p, cfg: cfg}
}

// Handler returns the root HTTP handler with CORS enabled.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /api/health", s.handleHealth)
	mux.HandleFunc("GET /api/anime", s.handleSearch)
	mux.HandleFunc("GET /api/anime/{id}", s.handleDetail)
	mux.HandleFunc("GET /api/season/{offset}", s.handleSeason)
	mux.HandleFunc("GET /api/latest", s.handleLatest)
	mux.HandleFunc("GET /api/genres", s.handleGenres)
	mux.HandleFunc("GET /api/tags", s.handleTags)
	mux.HandleFunc("GET /api/tracked", s.handleListTracked)
	mux.HandleFunc("POST /api/track", s.handleTrack)
	mux.HandleFunc("DELETE /api/track/{id}", s.handleUntrack)
	mux.HandleFunc("GET /api/stream", s.handleSSE)
	mux.HandleFunc("GET /api/status", s.handleStatus)

	return withCORS(withLogging(mux))
}

// --- Handlers ----------------------------------------------------------------

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"status":  "ok",
		"service": "anime-tracker",
		"time":    time.Now(),
	})
}

func (s *Server) handleSearch(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	opts := anilist.SearchOptions{
		Search:       strings.TrimSpace(q.Get("search")),
		Genre:        strings.TrimSpace(q.Get("genre")),
		Tag:          strings.TrimSpace(q.Get("tag")),
		Status:       strings.ToUpper(strings.TrimSpace(q.Get("status"))),
		Season:       strings.ToUpper(strings.TrimSpace(q.Get("season"))),
		Sort:         q.Get("sort"),
		Page:         atoiDefault(q.Get("page"), 1),
		PerPage:      atoiDefault(q.Get("perPage"), 20),
		IncludeAdult: s.cfg.IncludeAdult,
	}
	if opts.Season != "" && opts.SeasonYear == 0 {
		// allow explicit ?seasonYear=
	}
	opts.SeasonYear = atoiDefault(q.Get("seasonYear"), 0)

	page, err := s.client.Search(r.Context(), opts)
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	writeJSON(w, http.StatusOK, page)
}

func (s *Server) handleDetail(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(r.PathValue("id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, fmt.Errorf("invalid anime id"))
		return
	}
	anime, err := s.client.GetByID(r.Context(), id)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			writeError(w, http.StatusNotFound, err)
			return
		}
		writeError(w, http.StatusBadGateway, err)
		return
	}
	if anime.IsAdult && !s.cfg.IncludeAdult {
		writeError(w, http.StatusNotFound, fmt.Errorf("anime not found"))
		return
	}
	tracked, _ := s.store.IsTracked(id)
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"anime":   anime,
		"tracked": tracked,
	})
}

func (s *Server) handleSeason(w http.ResponseWriter, r *http.Request) {
	offset, err := strconv.Atoi(r.PathValue("offset"))
	if err != nil {
		writeError(w, http.StatusBadRequest, fmt.Errorf("invalid offset"))
		return
	}
	season, year := anilist.SeasonValue(time.Now(), offset)
	opts := anilist.SearchOptions{
		Season:       season,
		SeasonYear:   year,
		Status:       strings.ToUpper(strings.TrimSpace(r.URL.Query().Get("status"))),
		Genre:        strings.TrimSpace(r.URL.Query().Get("genre")),
		Tag:          strings.TrimSpace(r.URL.Query().Get("tag")),
		Sort:         anilist.SortTrending,
		Page:         atoiDefault(r.URL.Query().Get("page"), 1),
		PerPage:      atoiDefault(r.URL.Query().Get("perPage"), 24),
		IncludeAdult: s.cfg.IncludeAdult,
	}
	page, err := s.client.Search(r.Context(), opts)
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"season": season,
		"year":   year,
		"page":   page,
	})
}

func (s *Server) handleLatest(w http.ResponseWriter, r *http.Request) {
	status := strings.ToUpper(strings.TrimSpace(r.URL.Query().Get("status")))
	if status == "" {
		status = "RELEASING"
	}
	opts := anilist.AiringOptions{
		Status:       status,
		Genre:        strings.TrimSpace(r.URL.Query().Get("genre")),
		Tag:          strings.TrimSpace(r.URL.Query().Get("tag")),
		Sort:         anilist.SortUpdatedAt,
		Page:         atoiDefault(r.URL.Query().Get("page"), 1),
		PerPage:      atoiDefault(r.URL.Query().Get("perPage"), 24),
		IncludeAdult: s.cfg.IncludeAdult,
	}
	page, err := s.client.ListByStatus(r.Context(), opts)
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	writeJSON(w, http.StatusOK, page)
}

func (s *Server) handleGenres(w http.ResponseWriter, r *http.Request) {
	genres, err := s.client.Genres(r.Context())
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"genres": genres})
}

func (s *Server) handleTags(w http.ResponseWriter, r *http.Request) {
	tags, err := s.client.Tags(r.Context())
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"tags": tags})
}

func (s *Server) handleListTracked(w http.ResponseWriter, r *http.Request) {
	items, err := s.store.TrackedAnime()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (s *Server) handleTrack(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ID int `json:"id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, fmt.Errorf("invalid body"))
		return
	}
	if req.ID <= 0 {
		writeError(w, http.StatusBadRequest, fmt.Errorf("invalid anime id"))
		return
	}
	anime, err := s.client.GetByID(r.Context(), req.ID)
	if err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}
	if anime.IsAdult && !s.cfg.IncludeAdult {
		writeError(w, http.StatusNotFound, fmt.Errorf("anime not found"))
		return
	}
	if err := s.store.AddTracked(*anime); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	_ = s.store.PutMeta(metaOf(anime))
	writeJSON(w, http.StatusOK, map[string]interface{}{"tracked": true, "id": req.ID})
}

func (s *Server) handleUntrack(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(r.PathValue("id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, fmt.Errorf("invalid anime id"))
		return
	}
	if err := s.store.RemoveTracked(id); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"tracked": false, "id": id})
}

func (s *Server) handleStatus(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"poller": map[string]interface{}{
			"status":  s.poller.Status(),
			"lastRun": s.poller.LastRun(),
		},
		"config": map[string]interface{}{
			"includeAdult": s.cfg.IncludeAdult,
		},
	})
}

// handleSSE streams realtime update events.
func (s *Server) handleSSE(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		writeError(w, http.StatusInternalServerError, fmt.Errorf("streaming unsupported"))
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")

	sub := s.hub.Subscribe()
	defer s.hub.Unsubscribe(sub)

	// Initial heartbeat so clients know the stream is live.
	fmt.Fprint(w, ": connected\n\n")
	flusher.Flush()

	keepAlive := time.NewTicker(25 * time.Second)
	defer keepAlive.Stop()

	for {
		select {
		case <-r.Context().Done():
			return
		case <-keepAlive.C:
			if _, err := fmt.Fprint(w, ": ping\n\n"); err != nil {
				return
			}
			flusher.Flush()
		case raw := <-sub.Ch():
			if _, err := fmt.Fprintf(w, "data: %s\n\n", raw); err != nil {
				return
			}
			flusher.Flush()
		}
	}
}

// --- Helpers -----------------------------------------------------------------

func metaOf(a *anilist.Anime) store.Meta {
	if a == nil {
		return store.Meta{}
	}
	return store.Meta{
		ID:        a.ID,
		Episodes:  a.Episodes,
		Status:    a.Status,
		UpdatedAt: a.UpdatedAt,
	}
}

func atoiDefault(s string, def int) int {
	if s == "" {
		return def
	}
	n, err := strconv.Atoi(s)
	if err != nil {
		return def
	}
	return n
}

func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, err error) {
	writeJSON(w, status, map[string]interface{}{
		"error": map[string]interface{}{
			"code":    status,
			"message": err.Error(),
		},
	})
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func withLogging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		if !strings.HasPrefix(r.URL.Path, "/api/stream") {
			if q := r.URL.RawQuery; q != "" {
				fmt.Printf("%s %s?%s %s\n", r.Method, r.URL.Path, q, time.Since(start).Round(time.Millisecond))
			} else {
				fmt.Printf("%s %s %s\n", r.Method, r.URL.Path, time.Since(start).Round(time.Millisecond))
			}
		}
	})
}

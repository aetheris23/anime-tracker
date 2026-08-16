package poller

import (
	"context"
	"log"
	"sync"
	"time"

	"github.com/evosynx/anime-tracker/internal/anilist"
	"github.com/evosynx/anime-tracker/internal/hub"
	"github.com/evosynx/anime-tracker/internal/store"
)

// Poller periodically checks AniList for anime updates and publishes events.
type Poller struct {
	client *anilist.Client
	store  *store.Store
	hub    *hub.Hub
	cfg    Config

	mu     sync.Mutex
	lastAt time.Time
	status string
}

// Config tunes polling behaviour.
type Config struct {
	Interval time.Duration
	PerPage  int
	// ReleaseOnly restricts the "latest" scan to currently releasing entries.
	ReleaseOnly bool
	// IncludeAdult passes through adult titles in the recent-update feed.
	IncludeAdult bool
}

// DefaultConfig returns sane defaults.
func DefaultConfig() Config {
	return Config{
		Interval:     5 * time.Minute,
		PerPage:      20,
		ReleaseOnly:  true,
		IncludeAdult: true,
	}
}

// New creates a poller.
func New(client *anilist.Client, st *store.Store, h *hub.Hub, cfg Config) *Poller {
	return &Poller{client: client, store: st, hub: h, cfg: cfg}
}

// Run starts the poll loop and blocks until ctx is done.
func (p *Poller) Run(ctx context.Context) {
	if p.cfg.Interval <= 0 {
		p.cfg.Interval = time.Minute
	}
	ticker := time.NewTicker(p.cfg.Interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			p.poll(ctx)
		}
	}
}

// poll performs one update round.
func (p *Poller) poll(ctx context.Context) {
	start := time.Now()
	p.mu.Lock()
	p.status = "running"
	p.mu.Unlock()

	p.pollTracked(ctx)
	p.pollLatest(ctx)

	p.mu.Lock()
	p.lastAt = time.Now()
	p.status = "idle"
	dur := time.Since(start)
	p.mu.Unlock()

	log.Printf("poller: round finished in %s", dur)
}

// pollTracked checks each tracked anime for changes.
func (p *Poller) pollTracked(ctx context.Context) {
	tracked, err := p.store.TrackedAnime()
	if err != nil {
		log.Printf("poller: list tracked: %v", err)
		return
	}
	for _, t := range tracked {
		select {
		case <-ctx.Done():
			return
		default:
		}
		fresh, err := p.client.GetByID(ctx, t.Anime.ID)
		if err != nil {
			log.Printf("poller: fetch %d: %v", t.Anime.ID, err)
			continue
		}
		p.compareTracked(t, *fresh)
	}
}

func (p *Poller) compareTracked(old store.Tracked, fresh anilist.Anime) {
	notifications := detectChanges(old.Anime, fresh)
	if len(notifications) == 0 {
		return
	}
	for _, n := range notifications {
		p.hub.Publish("update", map[string]interface{}{
			"kind":  "tracked",
			"anime": fresh,
			"note":  n,
		})
	}
	if err := p.store.MarkNotified(fresh.ID); err != nil {
		log.Printf("poller: mark notified %d: %v", fresh.ID, err)
	}
	_ = p.store.PutMeta(metaOf(fresh))
	_ = p.store.AddTracked(fresh)
}

// pollLatest scans recently-updated airing anime for change detection.
func (p *Poller) pollLatest(ctx context.Context) {
	opts := anilist.AiringOptions{
		Status:       "RELEASING",
		Sort:         anilist.SortUpdatedAt,
		PerPage:      p.cfg.PerPage,
		IncludeAdult: p.cfg.IncludeAdult,
	}
	page, err := p.client.ListByStatus(ctx, opts)
	if err != nil {
		log.Printf("poller: latest scan: %v", err)
		return
	}
	for _, a := range page.Anime {
		select {
		case <-ctx.Done():
			return
		default:
		}
		p.rememberChange(a)
	}
}

// rememberChange compares fresh media with stored metadata and notifies.
func (p *Poller) rememberChange(a anilist.Anime) {
	meta, found, err := p.store.GetMeta(a.ID)
	if err != nil {
		log.Printf("poller: get meta %d: %v", a.ID, err)
		return
	}
	changed := false
	reason := ""

	switch {
	case !found:
		changed = true
		reason = "Anime baru ditemukan di musim ini"
	case changedEpisodes(meta.Episodes, a.Episodes):
		changed = true
		reason = newEpisodeReason(meta.Episodes, a.Episodes)
	case meta.UpdatedAt != a.UpdatedAt && meta.Status == "RELEASING" && a.Status != "RELEASING":
		changed = true
		reason = "Status berubah menjadi " + a.Status
	}

	if changed {
		p.hub.Publish("update", map[string]interface{}{
			"kind":  "latest",
			"anime": a,
			"note":  reason,
		})
	}
	_ = p.store.PutMeta(metaOf(a))
}

func detectChanges(old anilist.Anime, fresh anilist.Anime) []string {
	var notes []string
	if changedEpisodes(old.Episodes, fresh.Episodes) {
		notes = append(notes, newEpisodeReason(old.Episodes, fresh.Episodes))
	}
	if old.Status != fresh.Status && fresh.Status != "" {
		notes = append(notes, "Status berubah menjadi "+fresh.Status)
	}
	if old.AverageScore != nil && fresh.AverageScore != nil && *old.AverageScore != *fresh.AverageScore {
		notes = append(notes, "Skor berubah menjadi "+itoa(*fresh.AverageScore))
	}
	return notes
}

func changedEpisodes(old, fresh *int) bool {
	if fresh == nil {
		return false
	}
	if old == nil {
		return true
	}
	return *fresh > *old
}

func newEpisodeReason(old, fresh *int) string {
	if old == nil {
		if fresh != nil {
			return "Episode baru tayang (episode " + itoa(*fresh) + ")"
		}
		return "Episode baru tayang"
	}
	return "Episode baru tayang (episode " + itoa(*old) + " -> " + itoa(*fresh) + ")"
}

func metaOf(a anilist.Anime) store.Meta {
	return store.Meta{
		ID:        a.ID,
		Episodes:  a.Episodes,
		Status:    a.Status,
		UpdatedAt: a.UpdatedAt,
	}
}

func itoa(i int) string {
	const digits = "0123456789"
	if i == 0 {
		return "0"
	}
	neg := i < 0
	if neg {
		i = -i
	}
	var buf [20]byte
	pos := len(buf)
	for i > 0 {
		pos--
		buf[pos] = digits[i%10]
		i /= 10
	}
	if neg {
		pos--
		buf[pos] = '-'
	}
	return string(buf[pos:])
}

// LastRun returns when the last poll finished.
func (p *Poller) LastRun() time.Time {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.lastAt
}

// Status returns the current poller status.
func (p *Poller) Status() string {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.status
}

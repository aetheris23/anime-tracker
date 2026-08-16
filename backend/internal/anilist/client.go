package anilist

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const (
	apiURL         = "https://graphql.anilist.co"
	defaultPerPage = 20
	maxPerPage     = 50
)

// Client talks to the AniList GraphQL API.
type Client struct {
	http   *http.Client
	apiURL string
}

// NewClient creates a Client with sane defaults.
func NewClient() *Client {
	return &Client{
		http: &http.Client{
			Timeout: 30 * time.Second,
		},
		apiURL: apiURL,
	}
}

// gqlRequest executes a GraphQL operation and decodes the JSON payload.
func (c *Client) gqlRequest(ctx context.Context, query string, variables map[string]interface{}, out interface{}) error {
	payload := map[string]interface{}{
		"query":     query,
		"variables": variables,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.apiURL, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("anilist: http %d: %s", resp.StatusCode, truncate(raw, 300))
	}

	var envelope struct {
		Data   json.RawMessage `json:"data"`
		Errors []struct {
			Message string `json:"message"`
		} `json:"errors"`
	}
	if err := json.Unmarshal(raw, &envelope); err != nil {
		return fmt.Errorf("anilist: decode envelope: %w", err)
	}
	if len(envelope.Errors) > 0 {
		msgs := make([]string, 0, len(envelope.Errors))
		for _, e := range envelope.Errors {
			msgs = append(msgs, e.Message)
		}
		return errors.New("anilist: " + strings.Join(msgs, "; "))
	}
	if envelope.Data == nil {
		return errors.New("anilist: empty data payload")
	}
	return json.Unmarshal(envelope.Data, out)
}

func truncate(b []byte, n int) string {
	s := string(b)
	if len(s) > n {
		return s[:n] + "..."
	}
	return s
}

// Sort values used with the API.
const (
	SortPopularity = "POPULARITY_DESC"
	SortTrending   = "TRENDING_DESC"
	SortUpdatedAt  = "UPDATED_AT_DESC"
	SortScore      = "SCORE_DESC"
	SortStartDate  = "START_DATE_DESC"
)

// SearchOptions filters a search request.
type SearchOptions struct {
	Search       string
	Genre        string
	Tag          string
	Status       string
	Season       string
	SeasonYear   int
	Sort         string
	PerPage      int
	Page         int
	IncludeAdult bool
}

// Search returns a page of media matching the options.
func (c *Client) Search(ctx context.Context, opts SearchOptions) (*PageMeta, error) {
	if opts.PerPage <= 0 || opts.PerPage > maxPerPage {
		opts.PerPage = defaultPerPage
	}
	if opts.Page <= 0 {
		opts.Page = 1
	}
	if opts.Sort == "" {
		opts.Sort = SortPopularity
	}

	vars := map[string]interface{}{
		"search":  nilIfEmpty(opts.Search),
		"page":    opts.Page,
		"perPage": opts.PerPage,
		"type":    "ANIME",
		"genre":   nilIfEmpty(opts.Genre),
		"tag":     nilIfEmpty(opts.Tag),
		"status":  nilIfEmpty(opts.Status),
		"season":  nilIfEmpty(opts.Season),
		"sort":    []string{opts.Sort},
	}
	if opts.SeasonYear > 0 {
		vars["seasonYear"] = opts.SeasonYear
	}

	var resp PageResponse
	if err := c.gqlRequest(ctx, searchQuery, vars, &resp); err != nil {
		return nil, err
	}
	if resp.Page == nil {
		return nil, errors.New("anilist: no page data")
	}
	if !opts.IncludeAdult {
		resp.Page.Media = filterAdult(resp.Page.Media)
	}
	return &PageMeta{Anime: resp.Page.Media, Info: resp.Page.PageInfo}, nil
}

// GetByID fetches a single media entry.
func (c *Client) GetByID(ctx context.Context, id int) (*Anime, error) {
	vars := map[string]interface{}{"id": id}
	var resp AnimeResponse
	if err := c.gqlRequest(ctx, byIDQuery, vars, &resp); err != nil {
		return nil, err
	}
	if resp.Media == nil {
		return nil, fmt.Errorf("anilist: media %d not found", id)
	}
	return resp.Media, nil
}

// AiringOptions selects media by status for update tracking.
type AiringOptions struct {
	Status       string
	Genre        string
	Tag          string
	Sort         string
	PerPage      int
	Page         int
	IncludeAdult bool
}

// ListByStatus returns a page of media filtered by status (e.g. RELEASING).
func (c *Client) ListByStatus(ctx context.Context, opts AiringOptions) (*PageMeta, error) {
	if opts.PerPage <= 0 || opts.PerPage > maxPerPage {
		opts.PerPage = defaultPerPage
	}
	if opts.Page <= 0 {
		opts.Page = 1
	}
	if opts.Sort == "" {
		opts.Sort = SortUpdatedAt
	}

	vars := map[string]interface{}{
		"status":  nilIfEmpty(opts.Status),
		"genre":   nilIfEmpty(opts.Genre),
		"tag":     nilIfEmpty(opts.Tag),
		"page":    opts.Page,
		"perPage": opts.PerPage,
		"sort":    []string{opts.Sort},
	}

	var resp PageResponse
	if err := c.gqlRequest(ctx, airingQuery, vars, &resp); err != nil {
		return nil, err
	}
	if resp.Page == nil {
		return nil, errors.New("anilist: no page data")
	}
	if !opts.IncludeAdult {
		resp.Page.Media = filterAdult(resp.Page.Media)
	}
	return &PageMeta{Anime: resp.Page.Media, Info: resp.Page.PageInfo}, nil
}

// normalTags is a curated list of popular, non-adult AniList tags.
var normalTags = []string{
	"Isekai", "Harem", "School", "Shounen", "Shoujo", "Seinen", "Josei",
	"Historical", "Military", "Space", "Cyberpunk", "Super Power", "Time Travel",
	"Demons", "Vampire", "Detective", "Idol", "Politics", "Medical", "Survival",
	"Aliens", "Mythology", "Necromancy", "Steampunk", "Music", "Martial Arts",
	"Ninja", "Samurai", "Otaku Culture", "Magic", "Reincarnation",
}

// Tags returns the curated list of filter categories (tags).
func (c *Client) Tags(ctx context.Context) ([]string, error) {
	return normalTags, nil
}

// Genres returns the global list of anime genres, excluding adult categories.
func (c *Client) Genres(ctx context.Context) ([]string, error) {
	var resp struct {
		Genres []string `json:"GenreCollection"`
	}
	if err := c.gqlRequest(ctx, genresQuery, nil, &resp); err != nil {
		return nil, err
	}
	out := make([]string, 0, len(resp.Genres))
	for _, g := range resp.Genres {
		if strings.EqualFold(g, "Hentai") {
			continue
		}
		out = append(out, g)
	}
	return out, nil
}

// SeasonValue resolves a season name to the current/last/next season and year.
func SeasonValue(now time.Time, offset int) (season string, year int) {
	season, year = currentSeason(now)
	if offset == 0 {
		return season, year
	}
	return shiftedSeason(season, year, offset)
}

func currentSeason(t time.Time) (string, int) {
	m := int(t.Month())
	switch {
	case m >= 1 && m <= 3:
		return "WINTER", t.Year()
	case m >= 4 && m <= 6:
		return "SPRING", t.Year()
	case m >= 7 && m <= 9:
		return "SUMMER", t.Year()
	default:
		return "FALL", t.Year()
	}
}

func shiftedSeason(season string, year int, offset int) (string, int) {
	order := []string{"WINTER", "SPRING", "SUMMER", "FALL"}
	idx := 0
	for i, s := range order {
		if s == season {
			idx = i
			break
		}
	}
	total := idx + offset
	years := total / 4
	rem := total % 4
	if rem < 0 {
		rem += 4
		years--
	}
	return order[rem], year + years
}

func nilIfEmpty(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}

func filterAdult(in []Anime) []Anime {
	out := make([]Anime, 0, len(in))
	for _, a := range in {
		if !a.IsAdult {
			out = append(out, a)
		}
	}
	return out
}

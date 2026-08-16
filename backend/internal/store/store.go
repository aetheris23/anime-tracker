package store

import (
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"sync"
	"time"

	"go.etcd.io/bbolt"

	"github.com/evosynx/anime-tracker/internal/anilist"
)

var (
	bucketTracked = []byte("tracked")
	bucketMeta    = []byte("meta")

	// ErrNotFound is returned when a record is missing.
	ErrNotFound = errors.New("store: not found")
)

// Tracked is a user-tracked anime entry with notification settings.
type Tracked struct {
	Anime        anilist.Anime `json:"anime"`
	AddedAt      time.Time     `json:"addedAt"`
	LastNotified int64         `json:"lastNotified"`
}

// Meta is a lightweight pointer to a media entry used for change detection.
type Meta struct {
	ID        int    `json:"id"`
	Episodes  *int   `json:"episodes"`
	Status    string `json:"status"`
	UpdatedAt int64  `json:"updatedAt"`
	Season    string `json:"season"`
}

// Store is a thread-safe bbolt backed persistence layer.
type Store struct {
	db *bbolt.DB
	mu sync.RWMutex
}

// Open opens (or creates) the database file.
func Open(path string) (*Store, error) {
	db, err := bbolt.Open(path, 0o600, &bbolt.Options{Timeout: 3 * time.Second})
	if err != nil {
		return nil, err
	}
	err = db.Update(func(tx *bbolt.Tx) error {
		if _, err := tx.CreateBucketIfNotExists(bucketTracked); err != nil {
			return err
		}
		_, err := tx.CreateBucketIfNotExists(bucketMeta)
		return err
	})
	if err != nil {
		db.Close()
		return nil, err
	}
	return &Store{db: db}, nil
}

// Close closes the underlying database.
func (s *Store) Close() error {
	return s.db.Close()
}

// AddTracked saves a tracked anime.
func (s *Store) AddTracked(a anilist.Anime) error {
	t := Tracked{Anime: a, AddedAt: time.Now()}
	raw, err := json.Marshal(t)
	if err != nil {
		return err
	}
	return s.db.Update(func(tx *bbolt.Tx) error {
		return tx.Bucket(bucketTracked).Put(itob(a.ID), raw)
	})
}

// RemoveTracked deletes a tracked anime.
func (s *Store) RemoveTracked(id int) error {
	return s.db.Update(func(tx *bbolt.Tx) error {
		return tx.Bucket(bucketTracked).Delete(itob(id))
	})
}

// IsTracked reports whether an anime is tracked.
func (s *Store) IsTracked(id int) (bool, error) {
	found := false
	err := s.db.View(func(tx *bbolt.Tx) error {
		found = tx.Bucket(bucketTracked).Get(itob(id)) != nil
		return nil
	})
	return found, err
}

// TrackedAnime returns all tracked entries ordered by added time.
func (s *Store) TrackedAnime() ([]Tracked, error) {
	var out []Tracked
	err := s.db.View(func(tx *bbolt.Tx) error {
		return tx.Bucket(bucketTracked).ForEach(func(_, v []byte) error {
			var t Tracked
			if err := json.Unmarshal(v, &t); err != nil {
				return err
			}
			out = append(out, t)
			return nil
		})
	})
	return out, err
}

// GetMeta returns the stored metadata for change detection.
func (s *Store) GetMeta(id int) (Meta, bool, error) {
	var m Meta
	found := false
	err := s.db.View(func(tx *bbolt.Tx) error {
		raw := tx.Bucket(bucketMeta).Get(itob(id))
		if raw == nil {
			return nil
		}
		found = true
		return json.Unmarshal(raw, &m)
	})
	return m, found, err
}

// PutMeta stores metadata for change detection.
func (s *Store) PutMeta(m Meta) error {
	raw, err := json.Marshal(m)
	if err != nil {
		return err
	}
	return s.db.Update(func(tx *bbolt.Tx) error {
		return tx.Bucket(bucketMeta).Put(itob(m.ID), raw)
	})
}

// MarkNotified records the last notified time for a tracked entry.
func (s *Store) MarkNotified(id int) error {
	return s.db.Update(func(tx *bbolt.Tx) error {
		b := tx.Bucket(bucketTracked)
		raw := b.Get(itob(id))
		if raw == nil {
			return ErrNotFound
		}
		var t Tracked
		if err := json.Unmarshal(raw, &t); err != nil {
			return err
		}
		t.LastNotified = time.Now().Unix()
		nb, err := json.Marshal(t)
		if err != nil {
			return err
		}
		return b.Put(itob(id), nb)
	})
}

// FmtID converts an id key into a string for errors/logging.
func FmtID(id int) string { return strconv.Itoa(id) }

// KeyForIDs builds a human readable list of ids.
func KeyForIDs(ids []int) string {
	parts := make([]string, 0, len(ids))
	for _, id := range ids {
		parts = append(parts, strconv.Itoa(id))
	}
	return fmt.Sprintf("ids=[%s]", strings.Join(parts, ","))
}

func itob(v int) []byte {
	return []byte(strconv.Itoa(v))
}

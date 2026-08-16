package hub

import (
	"encoding/json"
	"log"
	"sync"
	"time"
)

// Event is pushed to subscribers over SSE.
type Event struct {
	Type string      `json:"type"`
	Data interface{} `json:"data"`
	At   time.Time   `json:"at"`
}

// Subscriber is a single SSE connection.
type Subscriber struct {
	ch   chan []byte
	done chan struct{}
	once sync.Once
}

// Close terminates the subscriber channel.
func (s *Subscriber) Close() {
	s.once.Do(func() { close(s.done) })
}

// Hub fans out events to all subscribers.
type Hub struct {
	mu   sync.Mutex
	subs map[*Subscriber]struct{}
}

// NewHub creates an empty hub.
func NewHub() *Hub {
	return &Hub{subs: make(map[*Subscriber]struct{})}
}

// Subscribe registers a new subscriber with a buffered channel.
func (h *Hub) Subscribe() *Subscriber {
	s := &Subscriber{ch: make(chan []byte, 64), done: make(chan struct{})}
	h.mu.Lock()
	h.subs[s] = struct{}{}
	h.mu.Unlock()
	return s
}

// Unsubscribe removes a subscriber.
func (h *Hub) Unsubscribe(s *Subscriber) {
	h.mu.Lock()
	if _, ok := h.subs[s]; ok {
		delete(h.subs, s)
		close(s.ch)
	}
	h.mu.Unlock()
	s.Close()
}

// Publish serializes an event and delivers it to all subscribers without blocking.
func (h *Hub) Publish(eventType string, data interface{}) {
	raw, err := json.Marshal(Event{Type: eventType, Data: data, At: time.Now()})
	if err != nil {
		log.Printf("hub: marshal event: %v", err)
		return
	}

	h.mu.Lock()
	defer h.mu.Unlock()
	for s := range h.subs {
		select {
		case s.ch <- raw:
		default:
			// Slow consumer: drop the event for this subscriber.
		}
	}
}

// Ch returns the receive channel of a subscriber.
func (s *Subscriber) Ch() <-chan []byte { return s.ch }

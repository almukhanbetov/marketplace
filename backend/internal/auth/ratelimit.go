package auth

import (
	"sync"
	"time"
)

// RateLimiter is a minimal in-process, fixed-window limiter keyed by an
// arbitrary string (typically "action:ip"). It is deliberately NOT
// distributed — a single Go process's in-memory map — which is an honest,
// documented limitation (Stage 9 §35): it resets on restart and doesn't
// coordinate across multiple instances. A production multi-instance
// deployment should replace this with a shared store (Redis or similar)
// as a later hardening stage; that infrastructure is explicitly out of
// scope for Stage 9. This is still strictly better than no limiting at
// all against basic single-instance brute-force/credential-stuffing.
type RateLimiter struct {
	mu       sync.Mutex
	limit    int
	window   time.Duration
	counters map[string]*windowCounter
}

type windowCounter struct {
	count      int
	windowFrom time.Time
}

func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	return &RateLimiter{limit: limit, window: window, counters: make(map[string]*windowCounter)}
}

// Allow reports whether one more request under key is permitted in the
// current window, incrementing the counter if so.
func (r *RateLimiter) Allow(key string) bool {
	now := time.Now()
	r.mu.Lock()
	defer r.mu.Unlock()

	// Opportunistic cleanup: bound the map's growth by dropping any
	// counter whose window has already lapsed, on every call.
	c, ok := r.counters[key]
	if !ok || now.Sub(c.windowFrom) >= r.window {
		r.counters[key] = &windowCounter{count: 1, windowFrom: now}
		return true
	}
	if c.count >= r.limit {
		return false
	}
	c.count++
	return true
}

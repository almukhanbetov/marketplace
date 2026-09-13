package models

import "errors"

// ErrNotFound is returned by repositories/services when a requested entity
// (category, product, seller) does not exist. Handlers map it to 404.
var ErrNotFound = errors.New("not found")

// ValidationError represents a client-supplied query/input value that
// failed validation (bad sort value, out-of-range rating, non-numeric
// price, ...). Handlers map it to 400 using Code/Message directly — both
// fields are always safe to show a client.
type ValidationError struct {
	Code    string
	Message string
}

func (e *ValidationError) Error() string {
	return e.Message
}

// NewValidationError builds a ValidationError with the given error code and
// client-safe message.
func NewValidationError(code, message string) *ValidationError {
	return &ValidationError{Code: code, Message: message}
}

// NotFoundError is a specific "entity not found" error carrying its own
// client-safe code/message. Plain ErrNotFound (+ a handler-supplied code)
// works when a service call can only fail not-found for one reason; Stage 5
// services that can fail not-found for more than one reason (e.g. adding a
// favorite: the user or the product might not exist) return this instead so
// the handler doesn't have to guess which one it was.
type NotFoundError struct {
	Code    string
	Message string
}

func (e *NotFoundError) Error() string { return e.Message }

func NewNotFoundError(code, message string) *NotFoundError {
	return &NotFoundError{Code: code, Message: message}
}

// ConflictError represents a request that is well-formed but cannot be
// satisfied given the current state of the data (an inactive seller offer,
// insufficient inventory, ...) — distinct from ValidationError (malformed
// input) and NotFoundError (the referenced entity doesn't exist at all).
type ConflictError struct {
	Code    string
	Message string
}

func (e *ConflictError) Error() string { return e.Message }

func NewConflictError(code, message string) *ConflictError {
	return &ConflictError{Code: code, Message: message}
}

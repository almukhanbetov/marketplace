package auth_test

import (
	"testing"

	"github.com/nova/marketplace-backend/internal/auth"
)

func TestHashPassword_NeverEqualsPlaintext(t *testing.T) {
	hash, err := auth.HashPassword("correcthorsebattery1")
	if err != nil {
		t.Fatalf("HashPassword() error = %v", err)
	}
	if hash == "correcthorsebattery1" {
		t.Fatal("hash equals the plaintext password")
	}
	if hash == "" {
		t.Fatal("hash is empty")
	}
}

func TestComparePassword_CorrectPassword_Succeeds(t *testing.T) {
	hash, err := auth.HashPassword("correcthorsebattery1")
	if err != nil {
		t.Fatalf("HashPassword() error = %v", err)
	}
	if err := auth.ComparePassword(hash, "correcthorsebattery1"); err != nil {
		t.Errorf("ComparePassword() with the correct password error = %v, want nil", err)
	}
}

func TestComparePassword_WrongPassword_Fails(t *testing.T) {
	hash, err := auth.HashPassword("correcthorsebattery1")
	if err != nil {
		t.Fatalf("HashPassword() error = %v", err)
	}
	if err := auth.ComparePassword(hash, "wrongpassword1"); err == nil {
		t.Error("ComparePassword() with the wrong password error = nil, want an error")
	}
}

func TestComparePassword_EmptyPassword_Fails(t *testing.T) {
	hash, err := auth.HashPassword("correcthorsebattery1")
	if err != nil {
		t.Fatalf("HashPassword() error = %v", err)
	}
	if err := auth.ComparePassword(hash, ""); err == nil {
		t.Error("ComparePassword() with an empty password error = nil, want an error")
	}
}

func TestComparePassword_MalformedHash_FailsNotPanics(t *testing.T) {
	if err := auth.ComparePassword("not-a-real-bcrypt-hash", "anything"); err == nil {
		t.Error("ComparePassword() with a malformed hash error = nil, want an error")
	}
}

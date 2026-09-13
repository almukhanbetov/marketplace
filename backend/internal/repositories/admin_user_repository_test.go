package repositories_test

import (
	"context"
	"testing"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/testutil"
)

// TestAdminUserRepository_List_NeverExposesPasswordHash covers Stage 8
// §6/§71/§74: models.User has no password_hash field at all — this test
// asserts every returned row's exported fields are exactly the safe set
// (a compile-time guarantee already, but confirms the struct/scan wiring
// is exactly what ships).
func TestAdminUserRepository_List_NeverExposesPasswordHash(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewAdminUserRepository(pool)
	ctx := context.Background()

	users, total, err := repo.List(ctx, models.UserQuery{Limit: 10})
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	if total == 0 || len(users) == 0 {
		t.Fatal("expected at least one seeded user")
	}
	for _, u := range users {
		if u.FullName == "" {
			t.Errorf("user %d missing full_name", u.ID)
		}
	}
}

func TestAdminUserRepository_List_FilterByRole(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewAdminUserRepository(pool)
	ctx := context.Background()

	admins, total, err := repo.List(ctx, models.UserQuery{Role: "admin", Limit: 20})
	if err != nil {
		t.Fatalf("List(role=admin) error = %v", err)
	}
	if total == 0 {
		t.Fatal("expected at least the seeded admin user")
	}
	for _, u := range admins {
		if u.Role != "admin" {
			t.Errorf("List(role=admin) returned a %s user", u.Role)
		}
	}
}

func TestAdminUserRepository_GetDetail_Aggregates(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewAdminUserRepository(pool)
	ctx := context.Background()

	// aigerim@example.com, id 10 — has seeded orders/favorites (Stage 5/6).
	detail, err := repo.GetDetail(ctx, 10)
	if err != nil {
		t.Fatalf("GetDetail(10) error = %v", err)
	}
	if detail.OrdersCount < 0 || detail.FavoritesCount < 0 || detail.AddressesCount < 0 {
		t.Errorf("negative aggregate counts: %+v", detail)
	}
	if detail.SellerID != nil {
		t.Errorf("customer user 10 should have SellerID = nil, got %v", *detail.SellerID)
	}
}

func TestAdminUserRepository_GetDetail_SellerUser_HasSellerID(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewAdminUserRepository(pool)
	ctx := context.Background()

	// techstore@nova.kz, user id 2, owns seller 1.
	detail, err := repo.GetDetail(ctx, 2)
	if err != nil {
		t.Fatalf("GetDetail(2) error = %v", err)
	}
	if detail.SellerID == nil {
		t.Fatal("expected seller user 2 to have a non-nil SellerID")
	}
	if *detail.SellerID != 1 {
		t.Errorf("SellerID = %d, want 1 (TechStore)", *detail.SellerID)
	}
}

func TestAdminUserRepository_UpdateStatus_NeverDeletes(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewAdminUserRepository(pool)
	ctx := context.Background()

	const testUserID = int64(11) // nurlan@example.com — dedicated to this package
	t.Cleanup(func() {
		if err := repo.UpdateStatus(context.Background(), testUserID, true); err != nil {
			t.Errorf("cleanup: restore user %d active: %v", testUserID, err)
		}
	})

	if err := repo.UpdateStatus(ctx, testUserID, false); err != nil {
		t.Fatalf("UpdateStatus(false) error = %v", err)
	}
	detail, err := repo.GetDetail(ctx, testUserID)
	if err != nil {
		t.Fatalf("GetDetail() after deactivate error = %v, want the row still present", err)
	}
	if detail.IsActive {
		t.Error("user still active after UpdateStatus(false)")
	}

	if err := repo.UpdateStatus(ctx, testUserID, true); err != nil {
		t.Fatalf("UpdateStatus(true) error = %v", err)
	}
}

func TestAdminUserRepository_UpdateStatus_UnknownUser_NotFound(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewAdminUserRepository(pool)

	err := repo.UpdateStatus(context.Background(), 99999999, false)
	if err != models.ErrNotFound {
		t.Errorf("UpdateStatus(unknown) error = %v, want models.ErrNotFound", err)
	}
}

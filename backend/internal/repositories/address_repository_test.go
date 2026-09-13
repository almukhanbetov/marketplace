package repositories_test

import (
	"context"
	"testing"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/testutil"
)

// addressUserID is a seeded user with no seeded address row (an admin/
// seller account, per seeds/seed_demo.go which only seeds addresses for
// the three customer emails) — a clean slate for these tests.
const addressUserID = int64(2) // techstore@nova.kz

func TestAddressRepository_ListCreateUpdateDelete(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewAddressRepository(pool)
	ctx := context.Background()

	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, `DELETE FROM addresses WHERE user_id = $1`, addressUserID)
	})

	created, err := repo.Create(ctx, addressUserID, models.AddressInput{
		City: "Алматы", Street: "ул. Тестовая", House: "1", IsDefault: true,
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if !created.IsDefault {
		t.Errorf("expected first address to be default, got IsDefault=false")
	}

	list, err := repo.List(ctx, addressUserID)
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	if len(list) != 1 || list[0].ID != created.ID {
		t.Fatalf("expected exactly the created address, got %+v", list)
	}

	updated, err := repo.Update(ctx, addressUserID, created.ID, models.AddressInput{
		City: "Астана", Street: "ул. Тестовая", House: "2", IsDefault: true,
	})
	if err != nil {
		t.Fatalf("Update() error = %v", err)
	}
	if updated.City != "Астана" || updated.House != "2" {
		t.Errorf("Update() did not persist new field values: %+v", updated)
	}

	if err := repo.Delete(ctx, addressUserID, created.ID); err != nil {
		t.Fatalf("Delete() error = %v", err)
	}
	list, err = repo.List(ctx, addressUserID)
	if err != nil {
		t.Fatalf("List() after delete error = %v", err)
	}
	if len(list) != 0 {
		t.Errorf("expected empty address list after Delete(), got %+v", list)
	}
}

// TestAddressRepository_DefaultSwitching_AtMostOneDefault covers Stage 5
// §19/§50: setting a new address as default must clear the previous one,
// and the partial unique index guarantees at most one ever exists.
func TestAddressRepository_DefaultSwitching_AtMostOneDefault(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewAddressRepository(pool)
	ctx := context.Background()

	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, `DELETE FROM addresses WHERE user_id = $1`, addressUserID)
	})

	a, err := repo.Create(ctx, addressUserID, models.AddressInput{City: "Алматы", Street: "ул. А", House: "1", IsDefault: true})
	if err != nil {
		t.Fatalf("create A: %v", err)
	}
	b, err := repo.Create(ctx, addressUserID, models.AddressInput{City: "Алматы", Street: "ул. Б", House: "2", IsDefault: true})
	if err != nil {
		t.Fatalf("create B: %v", err)
	}

	list, err := repo.List(ctx, addressUserID)
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	var defaults int
	for _, addr := range list {
		if addr.IsDefault {
			defaults++
		}
		if addr.ID == a.ID && addr.IsDefault {
			t.Error("address A should no longer be default after B was created as default")
		}
		if addr.ID == b.ID && !addr.IsDefault {
			t.Error("address B should be default")
		}
	}
	if defaults != 1 {
		t.Fatalf("expected exactly 1 default address, got %d", defaults)
	}

	// SetDefault back to A must flip it atomically too.
	if _, err := repo.SetDefault(ctx, addressUserID, a.ID); err != nil {
		t.Fatalf("SetDefault(A) error = %v", err)
	}
	list, err = repo.List(ctx, addressUserID)
	if err != nil {
		t.Fatalf("List() after SetDefault error = %v", err)
	}
	defaults = 0
	for _, addr := range list {
		if addr.IsDefault {
			defaults++
			if addr.ID != a.ID {
				t.Errorf("expected A (%d) to be the sole default, found default=%d", a.ID, addr.ID)
			}
		}
	}
	if defaults != 1 {
		t.Fatalf("expected exactly 1 default address after switching back, got %d", defaults)
	}
}

// TestAddressRepository_CrossUserProtected covers the same ownership rule
// as cart items (Stage 5 §16's principle applied consistently): an address
// id belonging to another user must be untouchable.
func TestAddressRepository_CrossUserProtected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewAddressRepository(pool)
	ctx := context.Background()

	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, `DELETE FROM addresses WHERE user_id = $1`, addressUserID)
	})

	addr, err := repo.Create(ctx, addressUserID, models.AddressInput{City: "Алматы", Street: "ул. А", House: "1"})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}

	const otherUserID = int64(3)
	if _, err := repo.Update(ctx, otherUserID, addr.ID, models.AddressInput{City: "X", Street: "Y", House: "1"}); err == nil {
		t.Error("expected Update() by a different user to fail")
	} else if nfErr, ok := err.(*models.NotFoundError); !ok || nfErr.Code != "ADDRESS_NOT_FOUND" {
		t.Errorf("expected ADDRESS_NOT_FOUND, got %v", err)
	}

	if err := repo.Delete(ctx, otherUserID, addr.ID); err == nil {
		t.Error("expected Delete() by a different user to fail")
	} else if nfErr, ok := err.(*models.NotFoundError); !ok || nfErr.Code != "ADDRESS_NOT_FOUND" {
		t.Errorf("expected ADDRESS_NOT_FOUND, got %v", err)
	}
}

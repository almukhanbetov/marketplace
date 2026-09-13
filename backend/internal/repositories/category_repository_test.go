package repositories_test

import (
	"context"
	"testing"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/testutil"
)

func TestCategoryRepository_ListActive(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewCategoryRepository(pool)

	categories, err := repo.ListActive(context.Background())
	if err != nil {
		t.Fatalf("ListActive() error = %v", err)
	}
	if len(categories) < 10 {
		t.Errorf("expected at least 10 seeded categories, got %d", len(categories))
	}
	for _, c := range categories {
		if !c.IsActive {
			t.Errorf("ListActive() returned inactive category %d", c.ID)
		}
		if c.Name.RU == "" || c.Name.KK == "" || c.Name.EN == "" {
			t.Errorf("category %d missing a localized name: %+v", c.ID, c.Name)
		}
	}

	// sorted by sort_order then id
	for i := 1; i < len(categories); i++ {
		prev, cur := categories[i-1], categories[i]
		if cur.SortOrder < prev.SortOrder {
			t.Errorf("categories not sorted by sort_order: %d (%d) before %d (%d)", prev.ID, prev.SortOrder, cur.ID, cur.SortOrder)
		}
	}
}

func TestCategoryRepository_GetByID_Found(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewCategoryRepository(pool)
	ctx := context.Background()

	all, err := repo.ListActive(ctx)
	if err != nil || len(all) == 0 {
		t.Fatalf("need at least one seeded category to run this test, err=%v", err)
	}

	got, err := repo.GetByID(ctx, all[0].ID)
	if err != nil {
		t.Fatalf("GetByID(%d) error = %v", all[0].ID, err)
	}
	if got.Slug != all[0].Slug {
		t.Errorf("GetByID(%d).Slug = %q, want %q", all[0].ID, got.Slug, all[0].Slug)
	}
}

func TestCategoryRepository_GetByID_NotFound(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewCategoryRepository(pool)

	_, err := repo.GetByID(context.Background(), 99999999)
	if err != models.ErrNotFound {
		t.Errorf("GetByID(unknown) error = %v, want models.ErrNotFound", err)
	}
}

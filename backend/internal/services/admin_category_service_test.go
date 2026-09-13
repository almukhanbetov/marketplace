package services_test

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/services"
	"github.com/nova/marketplace-backend/internal/testutil"
)

func newAdminCategoryTestService(pool *pgxpool.Pool) *services.AdminCategoryService {
	return services.NewAdminCategoryService(repositories.NewAdminCategoryRepository(pool))
}

func deleteTestCategory(t *testing.T, pool *pgxpool.Pool, id int64) {
	t.Helper()
	if _, err := pool.Exec(context.Background(), `DELETE FROM categories WHERE id = $1`, id); err != nil {
		t.Errorf("cleanup category %d: %v", id, err)
	}
}

// TestAdminCategoryService_Create_InvalidParent_Rejected covers Stage 8
// §18: a nonexistent parent_id must fail validation.
func TestAdminCategoryService_Create_InvalidParent_Rejected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAdminCategoryTestService(pool)
	ctx := context.Background()

	badParent := int64(99999999)
	_, err := service.Create(ctx, models.CreateCategoryInput{
		ParentID: &badParent, NameRU: "Т", NameKK: "Т", NameEN: "T", Slug: "admin-svc-test-bad-parent",
	})
	nfErr, ok := err.(*models.NotFoundError)
	if !ok || nfErr.Code != "CATEGORY_NOT_FOUND" {
		t.Errorf("Create(bad parent) error = %v, want *models.NotFoundError{CATEGORY_NOT_FOUND}", err)
	}
}

// TestAdminCategoryService_Update_SelfParent_Rejected covers Stage 8 §18:
// a category can never be its own parent.
func TestAdminCategoryService_Update_SelfParent_Rejected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAdminCategoryTestService(pool)
	ctx := context.Background()

	id, err := service.Create(ctx, models.CreateCategoryInput{NameRU: "А", NameKK: "А", NameEN: "A", Slug: "admin-svc-test-self-parent"})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	t.Cleanup(func() { deleteTestCategory(t, pool, id) })

	err = service.Update(ctx, id, models.UpdateCategoryInput{
		ParentID: &id, NameRU: "А", NameKK: "А", NameEN: "A", Slug: "admin-svc-test-self-parent",
	})
	ve, ok := err.(*models.ValidationError)
	if !ok || ve.Code != "INVALID_PARENT" {
		t.Errorf("Update(self as parent) error = %v, want *models.ValidationError{INVALID_PARENT}", err)
	}
}

// TestAdminCategoryService_Update_TwoLevelCycle_Rejected covers Stage 8
// §18: A is B's parent; setting A's parent to B would create a 2-level
// cycle and must be rejected without a full graph traversal.
func TestAdminCategoryService_Update_TwoLevelCycle_Rejected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAdminCategoryTestService(pool)
	ctx := context.Background()

	aID, err := service.Create(ctx, models.CreateCategoryInput{NameRU: "А", NameKK: "А", NameEN: "A", Slug: "admin-svc-test-cycle-a"})
	if err != nil {
		t.Fatalf("Create(A) error = %v", err)
	}
	t.Cleanup(func() { deleteTestCategory(t, pool, aID) })

	bID, err := service.Create(ctx, models.CreateCategoryInput{ParentID: &aID, NameRU: "Б", NameKK: "Б", NameEN: "B", Slug: "admin-svc-test-cycle-b"})
	if err != nil {
		t.Fatalf("Create(B, parent=A) error = %v", err)
	}
	t.Cleanup(func() { deleteTestCategory(t, pool, bID) })

	err = service.Update(ctx, aID, models.UpdateCategoryInput{
		ParentID: &bID, NameRU: "А", NameKK: "А", NameEN: "A", Slug: "admin-svc-test-cycle-a",
	})
	ve, ok := err.(*models.ValidationError)
	if !ok || ve.Code != "INVALID_PARENT" {
		t.Errorf("Update(A's parent = B, B's parent is A) error = %v, want *models.ValidationError{INVALID_PARENT}", err)
	}
}

// TestAdminCategoryService_UpdateStatus_NeverDeletes covers Stage 8 §19:
// deactivating a category never removes the row.
func TestAdminCategoryService_UpdateStatus_NeverDeletes(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAdminCategoryTestService(pool)
	repo := repositories.NewAdminCategoryRepository(pool)
	ctx := context.Background()

	id, err := service.Create(ctx, models.CreateCategoryInput{NameRU: "Г", NameKK: "Г", NameEN: "G", Slug: "admin-svc-test-status", IsActive: true})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	t.Cleanup(func() { deleteTestCategory(t, pool, id) })

	if err := service.UpdateStatus(ctx, id, false); err != nil {
		t.Fatalf("UpdateStatus(false) error = %v", err)
	}
	cat, err := repo.GetByID(ctx, id)
	if err != nil {
		t.Fatalf("GetByID() after deactivate error = %v, want the row still present", err)
	}
	if cat.IsActive {
		t.Error("category still active after UpdateStatus(false)")
	}
}

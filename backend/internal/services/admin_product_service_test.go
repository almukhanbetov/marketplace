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

func newAdminProductTestService(pool *pgxpool.Pool) *services.AdminProductService {
	return services.NewAdminProductService(
		repositories.NewAdminProductRepository(pool),
		repositories.NewAdminCategoryRepository(pool),
	)
}

func deleteTestAdminProduct(t *testing.T, pool *pgxpool.Pool, id int64) {
	t.Helper()
	ctx := context.Background()
	pool.Exec(ctx, `DELETE FROM product_images WHERE product_id = $1`, id)
	pool.Exec(ctx, `DELETE FROM products WHERE id = $1`, id)
}

// TestAdminProductService_Create_InvalidCategory_Rejected covers Stage 8
// §14: a nonexistent category_id must fail before any row is written.
func TestAdminProductService_Create_InvalidCategory_Rejected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAdminProductTestService(pool)
	ctx := context.Background()

	_, err := service.Create(ctx, models.CreateProductInput{
		CategoryID: 99999999, NameRU: "Т", NameKK: "Т", NameEN: "T", Slug: "admin-svc-test-bad-category",
	})
	nfErr, ok := err.(*models.NotFoundError)
	if !ok || nfErr.Code != "CATEGORY_NOT_FOUND" {
		t.Errorf("Create(bad category) error = %v, want *models.NotFoundError{CATEGORY_NOT_FOUND}", err)
	}
}

// TestAdminProductService_Create_WithImages_ThenReplace covers Stage 8
// §14/§15/§17: images are created transactionally with the product, and a
// later Update with a new Images slice replaces the set entirely.
func TestAdminProductService_Create_WithImages_ThenReplace(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAdminProductTestService(pool)
	ctx := context.Background()

	id, err := service.Create(ctx, models.CreateProductInput{
		CategoryID: 1, Brand: "TestBrand",
		NameRU: "Тестовый товар", NameKK: "Тест тауар", NameEN: "Test product",
		Slug: "admin-svc-test-create-images",
		Images: []models.ProductImageInput{
			{URL: "https://example.com/a.jpg", SortOrder: 0},
			{URL: "https://example.com/b.jpg", SortOrder: 1},
		},
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	t.Cleanup(func() { deleteTestAdminProduct(t, pool, id) })

	detail, err := service.GetDetail(ctx, id)
	if err != nil {
		t.Fatalf("GetDetail() error = %v", err)
	}
	if len(detail.Images) != 2 {
		t.Fatalf("expected 2 images, got %d", len(detail.Images))
	}
	// Neither image was marked primary — the first must become primary
	// automatically (Stage 8 §17).
	if !detail.Images[0].IsPrimary || detail.Images[0].URL != "https://example.com/a.jpg" {
		t.Errorf("expected the first image to be auto-marked primary, got %+v", detail.Images[0])
	}

	if err := service.Update(ctx, id, models.UpdateProductInput{
		CategoryID: 1, NameRU: "Тестовый товар", NameKK: "Тест тауар", NameEN: "Test product",
		Slug: "admin-svc-test-create-images",
		Images: []models.ProductImageInput{
			{URL: "https://example.com/c.jpg", SortOrder: 0},
		},
	}); err != nil {
		t.Fatalf("Update() error = %v", err)
	}

	detail, err = service.GetDetail(ctx, id)
	if err != nil {
		t.Fatalf("GetDetail() after update error = %v", err)
	}
	if len(detail.Images) != 1 || detail.Images[0].URL != "https://example.com/c.jpg" {
		t.Errorf("expected images fully replaced with just c.jpg, got %+v", detail.Images)
	}
}

// TestAdminProductService_Create_DuplicateSlug_NoPartialRow covers Stage
// 8 §70: a failed Create (duplicate slug) must leave absolutely nothing
// behind — the whole transaction rolls back, never a partial product.
func TestAdminProductService_Create_DuplicateSlug_NoPartialRow(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAdminProductTestService(pool)
	ctx := context.Background()

	id, err := service.Create(ctx, models.CreateProductInput{
		CategoryID: 1, NameRU: "А", NameKK: "А", NameEN: "A", Slug: "admin-svc-test-dup-slug",
	})
	if err != nil {
		t.Fatalf("first Create() error = %v", err)
	}
	t.Cleanup(func() { deleteTestAdminProduct(t, pool, id) })

	_, err = service.Create(ctx, models.CreateProductInput{
		CategoryID: 1, NameRU: "Б", NameKK: "Б", NameEN: "B", Slug: "admin-svc-test-dup-slug",
		Images: []models.ProductImageInput{{URL: "https://example.com/x.jpg"}},
	})
	ce, ok := err.(*models.ConflictError)
	if !ok || ce.Code != "SLUG_ALREADY_EXISTS" {
		t.Errorf("Create(duplicate slug) error = %v, want *models.ConflictError{SLUG_ALREADY_EXISTS}", err)
	}

	var count int
	pool.QueryRow(ctx, `SELECT COUNT(*) FROM products WHERE name_ru = 'Б'`).Scan(&count)
	if count != 0 {
		t.Errorf("a failed Create left %d product row(s) behind, want 0 (no partial product)", count)
	}
	pool.QueryRow(ctx, `SELECT COUNT(*) FROM product_images pi JOIN products p ON p.id = pi.product_id WHERE p.name_ru = 'Б'`).Scan(&count)
	if count != 0 {
		t.Errorf("a failed Create left %d product_images row(s) behind, want 0", count)
	}
}

// TestAdminProductService_UpdateStatus_PublicCatalogRegression covers
// Stage 8 §16/§63: deactivating hides a product from the public catalog;
// reactivating restores it.
func TestAdminProductService_UpdateStatus_PublicCatalogRegression(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAdminProductTestService(pool)
	publicRepo := repositories.NewProductRepository(pool)
	ctx := context.Background()

	id, err := service.Create(ctx, models.CreateProductInput{
		CategoryID: 1, NameRU: "В", NameKK: "В", NameEN: "V", Slug: "admin-svc-test-status-regression", IsActive: true,
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	t.Cleanup(func() { deleteTestAdminProduct(t, pool, id) })

	if _, err := publicRepo.GetByID(ctx, id); err != nil {
		t.Fatalf("public GetByID() before deactivate error = %v, want found", err)
	}

	if err := service.UpdateStatus(ctx, id, false); err != nil {
		t.Fatalf("UpdateStatus(false) error = %v", err)
	}
	if _, err := publicRepo.GetByID(ctx, id); err != models.ErrNotFound {
		t.Errorf("public GetByID() after deactivate error = %v, want models.ErrNotFound", err)
	}

	if err := service.UpdateStatus(ctx, id, true); err != nil {
		t.Fatalf("UpdateStatus(true) error = %v", err)
	}
	if _, err := publicRepo.GetByID(ctx, id); err != nil {
		t.Errorf("public GetByID() after reactivate error = %v, want found", err)
	}
}

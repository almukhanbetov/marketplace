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

// Seller-offer service tests are dedicated to seller 4 (GadgetPro) —
// entirely unreferenced by any Stage 5/6/7 fixture in any package (see
// order_service_test.go for why that isolation matters), so this file's
// offer creations/deletions can't race seller_offer_repository_test.go's
// use of seller 5 in a different package, nor payout_service_test.go's use
// of seller 7 in this same package (this package runs its tests
// sequentially anyway, but keeping allocations distinct makes that fact
// unnecessary to rely on).
const svcOfferTestSellerID = int64(4)

func newSellerOfferTestService(pool *pgxpool.Pool) *services.SellerOfferService {
	return services.NewSellerOfferService(
		repositories.NewSellerOfferRepository(pool),
		repositories.NewSellerRepository(pool),
		repositories.NewProductRepository(pool),
	)
}

func deleteTestOfferSvc(t *testing.T, pool *pgxpool.Pool, offerID int64) {
	t.Helper()
	ctx := context.Background()
	pool.Exec(ctx, `DELETE FROM inventory WHERE seller_offer_id = $1`, offerID)
	pool.Exec(ctx, `DELETE FROM seller_offers WHERE id = $1`, offerID)
}

// TestSellerOfferService_Create_InvalidProduct covers Stage 7 §7: creating
// an offer against a nonexistent product must fail validation before ever
// touching seller_offers.
func TestSellerOfferService_Create_InvalidProduct(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newSellerOfferTestService(pool)
	ctx := context.Background()

	_, err := service.Create(ctx, svcOfferTestSellerID, models.CreateOfferInput{
		ProductID: 99999999, SKU: "SKU-SVC-BAD-PRODUCT", Price: "1000.00", DeliveryDays: 0, Stock: 1,
	})
	nfErr, ok := err.(*models.NotFoundError)
	if !ok || nfErr.Code != "PRODUCT_NOT_FOUND" {
		t.Errorf("Create(unknown product) error = %v, want *models.NotFoundError{PRODUCT_NOT_FOUND}", err)
	}
}

// TestSellerOfferService_Create_NegativeStock_Rejected covers Stage 7 §7:
// stock must be >= 0.
func TestSellerOfferService_Create_NegativeStock_Rejected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newSellerOfferTestService(pool)
	ctx := context.Background()

	_, err := service.Create(ctx, svcOfferTestSellerID, models.CreateOfferInput{
		ProductID: 1, SKU: "SKU-SVC-NEG-STOCK", Price: "1000.00", DeliveryDays: 0, Stock: -1,
	})
	ve, ok := err.(*models.ValidationError)
	if !ok || ve.Code != "INVALID_STOCK" {
		t.Errorf("Create(stock=-1) error = %v, want *models.ValidationError{INVALID_STOCK}", err)
	}
}

// TestSellerOfferService_Create_InvalidPrice_Rejected covers Stage 7 §7:
// price must be a valid decimal amount.
func TestSellerOfferService_Create_InvalidPrice_Rejected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newSellerOfferTestService(pool)
	ctx := context.Background()

	_, err := service.Create(ctx, svcOfferTestSellerID, models.CreateOfferInput{
		ProductID: 1, SKU: "SKU-SVC-BAD-PRICE", Price: "not-a-number", DeliveryDays: 0, Stock: 1,
	})
	ve, ok := err.(*models.ValidationError)
	if !ok || ve.Code != "INVALID_PRICE" {
		t.Errorf("Create(price=not-a-number) error = %v, want *models.ValidationError{INVALID_PRICE}", err)
	}
}

// TestSellerOfferService_Create_NegativeDeliveryDays_Rejected covers
// Stage 7 §7: delivery_days must be >= 0.
func TestSellerOfferService_Create_NegativeDeliveryDays_Rejected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newSellerOfferTestService(pool)
	ctx := context.Background()

	_, err := service.Create(ctx, svcOfferTestSellerID, models.CreateOfferInput{
		ProductID: 1, SKU: "SKU-SVC-BAD-DAYS", Price: "1000.00", DeliveryDays: -1, Stock: 1,
	})
	ve, ok := err.(*models.ValidationError)
	if !ok || ve.Code != "INVALID_DELIVERY_DAYS" {
		t.Errorf("Create(delivery_days=-1) error = %v, want *models.ValidationError{INVALID_DELIVERY_DAYS}", err)
	}
}

// TestSellerOfferService_Create_Valid_ThenDuplicateSKU covers Stage 7 §7:
// a valid create succeeds, and the service maps the DB's unique-violation
// on a repeat SKU to a clean SKU_ALREADY_EXISTS conflict.
func TestSellerOfferService_Create_Valid_ThenDuplicateSKU(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newSellerOfferTestService(pool)
	ctx := context.Background()

	offerID, err := service.Create(ctx, svcOfferTestSellerID, models.CreateOfferInput{
		ProductID: 1, SKU: "SKU-SVC-VALID", Price: "25000.00", DeliveryDays: 2, Stock: 3,
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	t.Cleanup(func() { deleteTestOfferSvc(t, pool, offerID) })

	_, err = service.Create(ctx, svcOfferTestSellerID, models.CreateOfferInput{
		ProductID: 3, SKU: "SKU-SVC-VALID", Price: "26000.00", DeliveryDays: 2, Stock: 3,
	})
	ce, ok := err.(*models.ConflictError)
	if !ok || ce.Code != "SKU_ALREADY_EXISTS" {
		t.Errorf("Create(duplicate sku) error = %v, want *models.ConflictError{SKU_ALREADY_EXISTS}", err)
	}
}

// TestSellerOfferService_UpdateInventory_NegativeRejected covers Stage 7
// §11: available_quantity must be >= 0, checked before ever reaching the DB.
func TestSellerOfferService_UpdateInventory_NegativeRejected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newSellerOfferTestService(pool)
	ctx := context.Background()

	offerID, err := service.Create(ctx, svcOfferTestSellerID, models.CreateOfferInput{
		ProductID: 6, SKU: "SKU-SVC-INV-NEG", Price: "1000.00", DeliveryDays: 0, Stock: 5,
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	t.Cleanup(func() { deleteTestOfferSvc(t, pool, offerID) })

	err = service.UpdateInventory(ctx, svcOfferTestSellerID, offerID, -3)
	ve, ok := err.(*models.ValidationError)
	if !ok || ve.Code != "INVALID_STOCK" {
		t.Errorf("UpdateInventory(-3) error = %v, want *models.ValidationError{INVALID_STOCK}", err)
	}
}

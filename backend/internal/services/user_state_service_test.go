package services_test

import (
	"context"
	"testing"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/services"
	"github.com/nova/marketplace-backend/internal/testutil"
)

const (
	svcDemoUserID    = int64(10)
	svcNoCartUserID  = int64(1)
	svcSafeProductID = int64(25)
	svcOfferA        = int64(54) // product 27 — dedicated to this package, doesn't collide with repositories_test/handlers_test fixtures
)

func assertNotFoundCode(t *testing.T, err error, wantCode string) {
	t.Helper()
	nfErr, ok := err.(*models.NotFoundError)
	if !ok {
		t.Fatalf("expected *models.NotFoundError, got %T (%v)", err, err)
	}
	if nfErr.Code != wantCode {
		t.Errorf("error code = %q, want %q", nfErr.Code, wantCode)
	}
}

func TestFavoriteService_UnknownUser(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	svc := services.NewFavoriteService(
		repositories.NewFavoriteRepository(pool),
		repositories.NewUserRepository(pool),
		repositories.NewProductRepository(pool),
	)
	ctx := context.Background()

	if _, err := svc.List(ctx, 99999999); err == nil {
		t.Error("List() for unknown user: expected error, got nil")
	} else {
		assertNotFoundCode(t, err, "USER_NOT_FOUND")
	}

	if err := svc.Add(ctx, 99999999, svcSafeProductID); err == nil {
		t.Error("Add() for unknown user: expected error, got nil")
	} else {
		assertNotFoundCode(t, err, "USER_NOT_FOUND")
	}
}

func TestFavoriteService_UnknownProduct(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	svc := services.NewFavoriteService(
		repositories.NewFavoriteRepository(pool),
		repositories.NewUserRepository(pool),
		repositories.NewProductRepository(pool),
	)
	ctx := context.Background()

	err := svc.Add(ctx, svcDemoUserID, 99999999)
	if err == nil {
		t.Fatal("expected error for unknown product, got nil")
	}
	assertNotFoundCode(t, err, "PRODUCT_NOT_FOUND")
}

func TestCartService_UnknownUser(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	svc := services.NewCartService(repositories.NewCartRepository(pool), repositories.NewUserRepository(pool))
	ctx := context.Background()

	if _, err := svc.Get(ctx, 99999999); err == nil {
		t.Error("Get() for unknown user: expected error, got nil")
	} else {
		assertNotFoundCode(t, err, "USER_NOT_FOUND")
	}

	if _, err := svc.AddItem(ctx, 99999999, svcOfferA, 1); err == nil {
		t.Error("AddItem() for unknown user: expected error, got nil")
	} else {
		assertNotFoundCode(t, err, "USER_NOT_FOUND")
	}
}

// TestCartService_QuantityValidation covers Stage 5 §9/§14: quantity must
// be > 0, both for adding and updating an item — this validation belongs
// to the service layer, ahead of any database round trip.
func TestCartService_QuantityValidation(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	svc := services.NewCartService(repositories.NewCartRepository(pool), repositories.NewUserRepository(pool))
	ctx := context.Background()

	for _, qty := range []int{0, -1} {
		if _, err := svc.AddItem(ctx, svcDemoUserID, svcOfferA, qty); err == nil {
			t.Errorf("AddItem(quantity=%d): expected a validation error, got nil", qty)
		} else if _, ok := err.(*models.ValidationError); !ok {
			t.Errorf("AddItem(quantity=%d): expected *models.ValidationError, got %T", qty, err)
		}

		if _, err := svc.UpdateItemQuantity(ctx, svcDemoUserID, 1, qty); err == nil {
			t.Errorf("UpdateItemQuantity(quantity=%d): expected a validation error, got nil", qty)
		} else if _, ok := err.(*models.ValidationError); !ok {
			t.Errorf("UpdateItemQuantity(quantity=%d): expected *models.ValidationError, got %T", qty, err)
		}
	}
}

func TestAddressService_ValidationRequiredFields(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	svc := services.NewAddressService(repositories.NewAddressRepository(pool), repositories.NewUserRepository(pool))
	ctx := context.Background()

	cases := []models.AddressInput{
		{Street: "ул. А", House: "1"},     // missing city
		{City: "Алматы", House: "1"},      // missing street
		{City: "Алматы", Street: "ул. А"}, // missing house
	}
	for _, in := range cases {
		if _, err := svc.Create(ctx, svcNoCartUserID, in); err == nil {
			t.Errorf("Create(%+v): expected a validation error, got nil", in)
		} else if ve, ok := err.(*models.ValidationError); !ok || ve.Code != "VALIDATION_ERROR" {
			t.Errorf("Create(%+v): expected VALIDATION_ERROR, got %v", in, err)
		}
	}
}

func TestAddressService_UnknownUser(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	svc := services.NewAddressService(repositories.NewAddressRepository(pool), repositories.NewUserRepository(pool))
	ctx := context.Background()

	if _, err := svc.List(ctx, 99999999); err == nil {
		t.Error("List() for unknown user: expected error, got nil")
	} else {
		assertNotFoundCode(t, err, "USER_NOT_FOUND")
	}
}

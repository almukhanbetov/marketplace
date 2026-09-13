package services

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"sort"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/money"
	"github.com/nova/marketplace-backend/internal/repositories"
)

type OrderService struct {
	orderRepo *repositories.OrderRepository
	userRepo  *repositories.UserRepository
}

func NewOrderService(orderRepo *repositories.OrderRepository, userRepo *repositories.UserRepository) *OrderService {
	return &OrderService{orderRepo: orderRepo, userRepo: userRepo}
}

func (s *OrderService) requireUser(ctx context.Context, userID int64) error {
	exists, err := s.userRepo.Exists(ctx, userID)
	if err != nil {
		return err
	}
	if !exists {
		return models.NewNotFoundError("USER_NOT_FOUND", "User not found")
	}
	return nil
}

// CreateOrder is the Stage 6 core marketplace transaction (§2): load and
// lock the DB cart, revalidate every line against current catalog state
// (§18 — Stage 5's cart cache is not trusted), decrement inventory
// atomically, recompute every price/commission/total from scratch inside
// the transaction (§3 — nothing from the client is trusted except the
// chosen address and payment provider), write the order/order_items/
// commissions/payment/seller-balance rows, and only then clear the cart.
// Any failure rolls the whole thing back — no partial order ever exists.
func (s *OrderService) CreateOrder(ctx context.Context, userID int64, in models.CreateOrderInput) (*models.OrderDetail, error) {
	if err := s.requireUser(ctx, userID); err != nil {
		return nil, err
	}
	if !models.ValidPaymentProviders[in.PaymentProvider] {
		return nil, models.NewValidationError("VALIDATION_ERROR", "payment_provider must be one of: card, kaspi_mock, apple_pay_mock, google_pay_mock")
	}
	if in.AddressID <= 0 {
		return nil, models.NewValidationError("VALIDATION_ERROR", "address_id is required")
	}

	// Idempotent-replay fast path (Stage 6 §35/§65): a plain duplicate
	// submission never opens a second transaction at all.
	if in.IdempotencyKey != "" {
		existingID, err := s.orderRepo.FindOrderIDByIdempotencyKey(ctx, userID, in.IdempotencyKey)
		if err != nil {
			return nil, err
		}
		if existingID != nil {
			return s.orderRepo.GetOrderDetail(ctx, userID, *existingID)
		}
	}

	orderID, err := s.runOrderTransaction(ctx, userID, in)
	if err != nil {
		if errors.Is(err, errIdempotentRace) {
			// By the time a unique_violation is visible to us, the
			// concurrent transaction that won the race has already
			// committed (Postgres blocks a conflicting insert until the
			// other transaction resolves) — so this lookup reliably finds
			// it (Stage 6 §35/§65).
			existingID, lookupErr := s.orderRepo.FindOrderIDByIdempotencyKey(ctx, userID, in.IdempotencyKey)
			if lookupErr != nil {
				return nil, lookupErr
			}
			if existingID != nil {
				return s.orderRepo.GetOrderDetail(ctx, userID, *existingID)
			}
		}
		return nil, err
	}

	return s.orderRepo.GetOrderDetail(ctx, userID, orderID)
}

func (s *OrderService) runOrderTransaction(ctx context.Context, userID int64, in models.CreateOrderInput) (int64, error) {
	tx, err := s.orderRepo.Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("begin order transaction: %w", err)
	}
	defer tx.Rollback(ctx) // no-op after a successful Commit

	lines, err := s.orderRepo.LoadCartLinesForUpdate(ctx, tx, userID)
	if err != nil {
		return 0, err
	}
	if len(lines) == 0 {
		return 0, models.NewValidationError("CART_EMPTY", "Your cart is empty")
	}

	delivery, err := s.orderRepo.GetAddressSnapshot(ctx, tx, userID, in.AddressID)
	if err != nil {
		return 0, err
	}

	// Revalidate every line fresh — Stage 5's cart is not sufficient
	// (§18/§20): any inactive offer/seller/product aborts the whole order.
	for _, line := range lines {
		if !line.OfferActive || !line.SellerActive || !line.ProductActive {
			return 0, models.NewConflictError("OFFER_UNAVAILABLE", fmt.Sprintf("Seller offer %d is no longer available", line.SellerOfferID))
		}
	}

	// Atomically decrement stock, in the same deterministic seller_offer_id
	// order the rows were locked in (§56 — deadlock avoidance). Any single
	// insufficient line rolls back everything already decremented in this
	// same transaction (§21/§63).
	for _, line := range lines {
		ok, err := s.orderRepo.DecrementInventory(ctx, tx, line.SellerOfferID, line.Quantity)
		if err != nil {
			return 0, err
		}
		if !ok {
			return 0, models.NewConflictError("INSUFFICIENT_STOCK", fmt.Sprintf("Not enough stock for seller offer %d", line.SellerOfferID))
		}
	}

	// Recompute every total from the transaction-fresh, locked prices —
	// never from anything the client sent (§3/§19).
	type computedLine struct {
		line       repositories.CartLineForOrder
		totalPrice string
		commission string
		sellerAmt  string
	}
	computed := make([]computedLine, 0, len(lines))
	totals := make([]string, 0, len(lines))
	commissions := make([]string, 0, len(lines))
	for _, line := range lines {
		if err := parsePositiveMoney(line.Price); err != nil {
			return 0, fmt.Errorf("invalid offer price for offer %d: %w", line.SellerOfferID, err)
		}
		totalPrice := money.Multiply(line.Price, line.Quantity)
		commission, sellerAmt := commissionSplit(totalPrice)
		computed = append(computed, computedLine{line: line, totalPrice: totalPrice, commission: commission, sellerAmt: sellerAmt})
		totals = append(totals, totalPrice)
		commissions = append(commissions, commission)
	}

	const deliveryTotal = "0.00" // Stage 6 §26: no logistics backend yet, flat free delivery.
	const discountTotal = "0.00"
	subtotal := money.Sum(totals...)
	commissionTotal := money.Sum(commissions...)
	orderTotal := money.Sum(subtotal, deliveryTotal) // discount_total is 0 (§25) — not subtracted here since it's already 0; kept explicit for clarity of the documented formula.

	orderID, err := s.orderRepo.CreateOrder(ctx, tx, userID, in.AddressID, *delivery, subtotal, deliveryTotal, commissionTotal, orderTotal, in.IdempotencyKey)
	if err != nil {
		if repositories.IsUniqueViolation(err) {
			// Lost the race to a concurrent identical submission (§35/§36)
			// — this transaction contributes nothing; the winner's order
			// is what CreateOrder's caller will fetch and return.
			return 0, errIdempotentRace
		}
		return 0, fmt.Errorf("create order: %w", err)
	}

	sellerPendingCents := map[int64]int64{}
	for _, c := range computed {
		orderItemID, err := s.orderRepo.CreateOrderItem(ctx, tx, orderID, repositories.OrderItemInsert{
			SellerID:         c.line.SellerID,
			ProductID:        c.line.ProductID,
			SellerOfferID:    c.line.SellerOfferID,
			ProductName:      c.line.ProductNameRU, // canonical snapshot language — Stage 6 §14
			SKU:              c.line.SKU,
			Quantity:         c.line.Quantity,
			UnitPrice:        c.line.Price,
			TotalPrice:       c.totalPrice,
			CommissionRate:   DefaultCommissionRate,
			CommissionAmount: c.commission,
			SellerAmount:     c.sellerAmt,
		})
		if err != nil {
			return 0, err
		}
		if err := s.orderRepo.CreateCommission(ctx, tx, orderItemID, c.line.SellerID, DefaultCommissionRate, c.commission); err != nil {
			return 0, err
		}
		sellerPendingCents[c.line.SellerID] += money.ToCents(c.sellerAmt)
	}

	// Credit each seller's PENDING balance once per seller (not once per
	// item), in ascending seller_id order for deadlock avoidance (§56),
	// consistent with §22: funds land in pending_amount, never
	// available_amount, until a later delivery/return stage confirms them.
	sellerIDs := make([]int64, 0, len(sellerPendingCents))
	for id := range sellerPendingCents {
		sellerIDs = append(sellerIDs, id)
	}
	sort.Slice(sellerIDs, func(i, j int) bool { return sellerIDs[i] < sellerIDs[j] })
	for _, sellerID := range sellerIDs {
		if err := s.orderRepo.AddSellerPendingBalance(ctx, tx, sellerID, money.FromCents(sellerPendingCents[sellerID])); err != nil {
			return 0, err
		}
	}

	// Stage 6 mock payment: always succeeds immediately for all four
	// supported providers — this is a simulation, never a real gateway
	// call (§9/§55 — a real integration must not run inside a DB
	// transaction holding row locks the way this mock harmlessly does).
	externalRef, err := mockExternalReference(orderID)
	if err != nil {
		return 0, err
	}
	if err := s.orderRepo.CreatePayment(ctx, tx, orderID, in.PaymentProvider, "paid", orderTotal, externalRef); err != nil {
		return 0, err
	}
	if err := s.orderRepo.UpdateOrderStatus(ctx, tx, orderID, models.OrderStatusPaid); err != nil {
		return 0, err
	}

	// Cart clears only once every other step has succeeded — if anything
	// above returned an error, this line never runs and the deferred
	// Rollback leaves the cart exactly as it was (§33/§34).
	if err := s.orderRepo.ClearCartItems(ctx, tx, userID); err != nil {
		return 0, err
	}

	if err := tx.Commit(ctx); err != nil {
		return 0, fmt.Errorf("commit order transaction: %w", err)
	}

	return orderID, nil
}

// errIdempotentRace signals CreateOrder to re-resolve the idempotency key
// after this transaction lost a concurrent-insert race — never returned to
// a handler directly.
var errIdempotentRace = errors.New("idempotent race: order already created by a concurrent request")

// mockExternalReference produces a safe, non-guessable mock payment
// reference — never a real gateway token, purely cosmetic (Stage 6 §10).
func mockExternalReference(orderID int64) (string, error) {
	buf := make([]byte, 6)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("generate mock payment reference: %w", err)
	}
	return fmt.Sprintf("MOCK-ORD-%d-%s", orderID, hex.EncodeToString(buf)), nil
}

// GetOrders returns the user's order history, newest first.
func (s *OrderService) GetOrders(ctx context.Context, userID int64) ([]models.OrderSummary, error) {
	if err := s.requireUser(ctx, userID); err != nil {
		return nil, err
	}
	return s.orderRepo.ListOrders(ctx, userID)
}

// GetOrder returns one order, scoped to userID (§53 — an order id
// belonging to another user is a 404, never a cross-user leak).
func (s *OrderService) GetOrder(ctx context.Context, userID, orderID int64) (*models.OrderDetail, error) {
	if err := s.requireUser(ctx, userID); err != nil {
		return nil, err
	}
	return s.orderRepo.GetOrderDetail(ctx, userID, orderID)
}

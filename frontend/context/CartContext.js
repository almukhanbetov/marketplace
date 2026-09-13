"use client";

import { createContext, useContext, useEffect, useState, useCallback, useMemo } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";
import { getCart, addCartItem, updateCartItemQuantity, removeCartItem, clearCart as clearCartApi } from "@/lib/api/cart";
import { adaptCart } from "@/lib/api/adapters";
import { useAuth } from "@/context/AuthContext";
import { useModal } from "@/context/ModalContext";

const EMPTY_RAW_CART = { id: null, items: [], summary: { item_count: 0, subtotal: "0" } };

const CartContext = createContext(null);

/**
 * Backend-backed cart (Stage 5) — the demo user's DB cart is the sole
 * source of truth; nothing here is persisted to localStorage. Every
 * mutation sends only { seller_offer_id, quantity } and replaces local
 * state with whatever the backend returns (current, authoritative prices —
 * never trusted from the client, §12). Mutations that fail show a toast
 * and leave state at its last-known-good value rather than a stale
 * optimistic guess (§35).
 */
export function CartProvider({ children }) {
  const { lang, t } = useLanguage();
  const { showToast } = useToast();
  const { mounted, isAuthenticated } = useAuth();
  const { openModal } = useModal();
  const [rawCart, setRawCart] = useState(EMPTY_RAW_CART);
  const [loading, setLoading] = useState(true);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [bump, setBump] = useState(false);

  // Re-derived from the raw backend response whenever the language
  // changes, so switching RU/KAZ/ENG re-localizes product titles without a
  // network round trip (same pattern as FavoritesContext).
  const cart = useMemo(() => adaptCart(rawCart, lang), [rawCart, lang]);

  const applyRaw = useCallback((raw) => setRawCart(raw), []);

  // Stage 9 §48: a logged-out visitor gets a neutral empty cart — no
  // anonymous DB cart is ever created or read (the backend would 401
  // anyway). The cart only ever reflects the authenticated user's own DB
  // row, and is cleared the instant they log out.
  const refreshCart = useCallback(async () => {
    if (!isAuthenticated) {
      setRawCart(EMPTY_RAW_CART);
      return;
    }
    try {
      const raw = await getCart();
      applyRaw(raw);
    } catch {
      // Backend unreachable — keep whatever was last loaded rather than
      // wiping a working cart view (§35: no crash, no silent stale-as-truth
      // localStorage fallback — there is none here to fall back to).
    }
  }, [applyRaw, isAuthenticated]);

  useEffect(() => {
    if (!mounted) return;
    refreshCart().finally(() => setLoading(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mounted, isAuthenticated]);

  function failWithToast(err, fallbackMessage) {
    const message = err?.status && err.status !== 500 ? err.message : fallbackMessage;
    showToast(message || fallbackMessage, "warn", "⚠");
  }

  const addToCart = useCallback(
    async (product, qty = 1) => {
      if (!isAuthenticated) {
        showToast(t("loginRequired"), "info", "🔑");
        openModal("login");
        return;
      }
      if (!product?.sellerOfferId) {
        showToast(lang === "en" ? "This item can't be added to the cart right now." : "Этот товар пока нельзя добавить в корзину.", "warn", "⚠");
        return;
      }
      try {
        const raw = await addCartItem(product.sellerOfferId, qty);
        applyRaw(raw);
        setBump(true);
        setTimeout(() => setBump(false), 400);
        showToast(t("addedToCart"), "success", "✓");
      } catch (err) {
        failWithToast(err, lang === "en" ? "Couldn't add item to cart." : "Не удалось добавить товар в корзину.");
      }
    },
    [applyRaw, lang, t, showToast, isAuthenticated, openModal]
  );

  const setQty = useCallback(
    async (itemId, quantity) => {
      if (quantity <= 0) return;
      try {
        const raw = await updateCartItemQuantity(itemId, quantity);
        applyRaw(raw);
      } catch (err) {
        failWithToast(err, lang === "en" ? "Couldn't update quantity." : "Не удалось изменить количество.");
      }
    },
    [applyRaw, lang]
  );

  const increaseQuantity = useCallback(
    (itemId) => {
      const item = cart.items.find((i) => i.id === itemId);
      if (!item) return;
      return setQty(itemId, item.qty + 1);
    },
    [cart.items, setQty]
  );

  const decreaseQuantity = useCallback(
    async (itemId) => {
      const item = cart.items.find((i) => i.id === itemId);
      if (!item) return;
      if (item.qty <= 1) {
        try {
          const raw = await removeCartItem(itemId);
          applyRaw(raw);
        } catch (err) {
          failWithToast(err, lang === "en" ? "Couldn't remove item." : "Не удалось удалить товар.");
        }
        return;
      }
      return setQty(itemId, item.qty - 1);
    },
    [cart.items, setQty, applyRaw, lang]
  );

  const removeFromCart = useCallback(
    async (itemId) => {
      try {
        const raw = await removeCartItem(itemId);
        applyRaw(raw);
      } catch (err) {
        failWithToast(err, lang === "en" ? "Couldn't remove item." : "Не удалось удалить товар.");
      }
    },
    [applyRaw, lang]
  );

  const clearCart = useCallback(async () => {
    try {
      const raw = await clearCartApi();
      applyRaw(raw);
    } catch (err) {
      failWithToast(err, lang === "en" ? "Couldn't clear cart." : "Не удалось очистить корзину.");
    }
  }, [applyRaw, lang]);

  const hasProduct = useCallback((productId) => cart.items.some((i) => i.product.id === productId), [cart.items]);
  const getItemByOffer = useCallback((sellerOfferId) => cart.items.find((i) => i.sellerOfferId === sellerOfferId), [cart.items]);
  const getCartCount = useCallback(() => cart.itemCount, [cart.itemCount]);

  const getCartTotal = useCallback(() => {
    let subtotal = 0;
    let oldSubtotal = 0;
    cart.items.forEach((i) => {
      subtotal += i.product.price * i.qty;
      oldSubtotal += i.product.oldPrice * i.qty;
    });
    const discount = oldSubtotal - subtotal;
    const shipping = subtotal > 0 && subtotal < 20000 ? 1500 : 0;
    return { subtotal, discount, shipping, total: subtotal + shipping };
  }, [cart.items]);

  const groupBySeller = useCallback(() => {
    const groups = {};
    cart.items.forEach((i) => {
      const key = i.product.seller || "—";
      if (!groups[key]) groups[key] = { seller: key, rating: i.product.sellerRating, items: [] };
      groups[key].items.push(i);
    });
    return Object.values(groups);
  }, [cart.items]);

  const openDrawer = useCallback(() => setDrawerOpen(true), []);
  const closeDrawer = useCallback(() => setDrawerOpen(false), []);

  const value = useMemo(
    () => ({
      items: cart.items,
      count: cart.itemCount,
      loading,
      bump,
      drawerOpen,
      openDrawer,
      closeDrawer,
      addToCart,
      setQty,
      increaseQuantity,
      decreaseQuantity,
      removeFromCart,
      clearCart,
      hasProduct,
      getItemByOffer,
      getCartCount,
      getCartTotal,
      groupBySeller,
      refreshCart,
    }),
    [
      cart.items, cart.itemCount, loading, bump, drawerOpen, openDrawer, closeDrawer,
      addToCart, setQty, increaseQuantity, decreaseQuantity, removeFromCart, clearCart,
      hasProduct, getItemByOffer, getCartCount, getCartTotal, groupBySeller, refreshCart,
    ]
  );

  return <CartContext.Provider value={value}>{children}</CartContext.Provider>;
}

export function useCart() {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error("useCart must be used within CartProvider");
  return ctx;
}

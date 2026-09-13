import { apiFetch } from "@/lib/api/client";

export async function getCart() {
  const res = await apiFetch("/me/cart");
  return res.data;
}

/** Only seller_offer_id + quantity are ever sent — the backend is the
 * sole authority on price (Stage 5 §12). */
export async function addCartItem(sellerOfferId, quantity) {
  const res = await apiFetch("/me/cart/items", {
    method: "POST",
    body: JSON.stringify({ seller_offer_id: sellerOfferId, quantity }),
  });
  return res.data;
}

export async function updateCartItemQuantity(itemId, quantity) {
  const res = await apiFetch(`/me/cart/items/${itemId}`, {
    method: "PATCH",
    body: JSON.stringify({ quantity }),
  });
  return res.data;
}

export async function removeCartItem(itemId) {
  const res = await apiFetch(`/me/cart/items/${itemId}`, { method: "DELETE" });
  return res.data;
}

export async function clearCart() {
  const res = await apiFetch("/me/cart", { method: "DELETE" });
  return res.data;
}

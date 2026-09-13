import { apiFetch } from "@/lib/api/client";

/** Seller orders are READ-ONLY (Stage 7 §16/§17) — there is no
 * status-update call here on purpose. The schema has no per-seller
 * fulfillment/suborder entity, so a seller dashboard can't safely mutate
 * the single global order status without corrupting other sellers'/the
 * customer's view of the same order. */
export async function getSellerOrders(params = {}) {
  const res = await apiFetch("/seller/orders", { params });
  return { items: res.data ?? [], meta: res.meta ?? { limit: 0, offset: 0, total: 0 } };
}

export async function getSellerOrder(orderId) {
  const res = await apiFetch(`/seller/orders/${orderId}`);
  return res.data;
}

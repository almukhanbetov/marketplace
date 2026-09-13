import { apiFetch } from "@/lib/api/client";

/** Only address_id/payment_provider are ever sent — the backend derives
 * every price/total from the current DB cart (Stage 6 §3) and the user id
 * exclusively from the authenticated caller (Stage 9 §50/§51). idempotencyKey
 * is sent as the Idempotency-Key header so a double-submit (double click,
 * retried network failure) safely resolves to the same order instead of
 * creating a duplicate. */
export async function createOrder({ addressId, paymentProvider }, idempotencyKey) {
  const res = await apiFetch("/me/orders", {
    method: "POST",
    headers: idempotencyKey ? { "Idempotency-Key": idempotencyKey } : undefined,
    body: JSON.stringify({ address_id: addressId, payment_provider: paymentProvider }),
  });
  return res.data;
}

export async function getOrders() {
  const res = await apiFetch("/me/orders");
  return res.data ?? [];
}

export async function getOrder(orderId) {
  const res = await apiFetch(`/me/orders/${orderId}`);
  return res.data;
}

import { apiFetch } from "@/lib/api/client";

export async function getSellerPayouts() {
  const res = await apiFetch("/seller/payouts");
  return res.data ?? [];
}

/** amount is a decimal string (e.g. "50000.00"). idempotencyKey guards
 * against a double-submit creating two payout requests (Stage 7 §24) —
 * same pattern as createOrder's Idempotency-Key header. The backend is
 * authoritative on whether available balance covers it; this call never
 * pre-validates beyond what the caller already did client-side. */
export async function createSellerPayout(amount, idempotencyKey) {
  const res = await apiFetch("/seller/payouts", {
    method: "POST",
    headers: idempotencyKey ? { "Idempotency-Key": idempotencyKey } : undefined,
    body: JSON.stringify({ amount }),
  });
  return res.data;
}

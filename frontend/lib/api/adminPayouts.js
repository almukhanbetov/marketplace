import { apiFetch } from "@/lib/api/client";

export async function getAdminPayouts(params = {}) {
  const res = await apiFetch("/admin/payouts", { params });
  return { items: res.data ?? [], meta: res.meta ?? { limit: 0, offset: 0, total: 0 } };
}

/** status must be one of the allowed transitions the backend's payout
 * state machine accepts from the payout's current status (Stage 8 §26):
 * pending->processing, pending->rejected, processing->paid,
 * processing->rejected. Any other transition is rejected by the backend
 * with INVALID_PAYOUT_STATUS_TRANSITION. */
export async function setAdminPayoutStatus(id, status) {
  const res = await apiFetch(`/admin/payouts/${id}/status`, {
    method: "PATCH",
    body: JSON.stringify({ status }),
  });
  return res.data;
}

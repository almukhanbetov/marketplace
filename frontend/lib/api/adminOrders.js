import { apiFetch } from "@/lib/api/client";

/** Admin orders are read-only (Stage 8 §22) — no status-update call here
 * on purpose. */
export async function getAdminOrders(params = {}) {
  const res = await apiFetch("/admin/orders", { params });
  return { items: res.data ?? [], meta: res.meta ?? { limit: 0, offset: 0, total: 0 } };
}

export async function getAdminOrder(id) {
  const res = await apiFetch(`/admin/orders/${id}`);
  return res.data;
}

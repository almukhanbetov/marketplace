import { apiFetch } from "@/lib/api/client";

export async function getAdminPayments(params = {}) {
  const res = await apiFetch("/admin/payments", { params });
  return { items: res.data ?? [], meta: res.meta ?? { limit: 0, offset: 0, total: 0 } };
}

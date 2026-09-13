import { apiFetch } from "@/lib/api/client";

export async function getAdminCommissions(params = {}) {
  const res = await apiFetch("/admin/commissions", { params });
  return { items: res.data ?? [], meta: res.meta ?? { limit: 0, offset: 0, total: 0 } };
}

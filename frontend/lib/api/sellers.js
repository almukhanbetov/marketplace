import { apiFetch } from "@/lib/api/client";

export async function getSellers() {
  const res = await apiFetch("/sellers");
  return res.data ?? [];
}

export async function getSeller(id) {
  const res = await apiFetch(`/sellers/${id}`);
  return res.data;
}

export async function getSellerProducts(id, params = {}) {
  const res = await apiFetch(`/sellers/${id}/products`, { params });
  return { items: res.data ?? [], meta: res.meta ?? { limit: 0, offset: 0, total: 0 } };
}

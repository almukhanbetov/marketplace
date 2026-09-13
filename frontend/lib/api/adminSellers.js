import { apiFetch } from "@/lib/api/client";

export async function getAdminSellers(params = {}) {
  const res = await apiFetch("/admin/sellers", { params });
  return { items: res.data ?? [], meta: res.meta ?? { limit: 0, offset: 0, total: 0 } };
}

export async function getAdminSeller(id) {
  const res = await apiFetch(`/admin/sellers/${id}`);
  return res.data;
}

export async function setAdminSellerStatus(id, isActive) {
  const res = await apiFetch(`/admin/sellers/${id}/status`, {
    method: "PATCH",
    body: JSON.stringify({ is_active: isActive }),
  });
  return res.data;
}

export async function setAdminSellerVerification(id, isVerified) {
  const res = await apiFetch(`/admin/sellers/${id}/verification`, {
    method: "PATCH",
    body: JSON.stringify({ is_verified: isVerified }),
  });
  return res.data;
}

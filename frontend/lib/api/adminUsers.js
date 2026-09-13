import { apiFetch } from "@/lib/api/client";

export async function getAdminUsers(params = {}) {
  const res = await apiFetch("/admin/users", { params });
  return { items: res.data ?? [], meta: res.meta ?? { limit: 0, offset: 0, total: 0 } };
}

export async function getAdminUser(id) {
  const res = await apiFetch(`/admin/users/${id}`);
  return res.data;
}

export async function setAdminUserStatus(id, isActive) {
  const res = await apiFetch(`/admin/users/${id}/status`, {
    method: "PATCH",
    body: JSON.stringify({ is_active: isActive }),
  });
  return res.data;
}

import { apiFetch } from "@/lib/api/client";

export async function getAdminReviews(params = {}) {
  const res = await apiFetch("/admin/reviews", { params });
  return { items: res.data ?? [], meta: res.meta ?? { limit: 0, offset: 0, total: 0 } };
}

export async function setAdminReviewVisibility(id, isVisible) {
  const res = await apiFetch(`/admin/reviews/${id}/visibility`, {
    method: "PATCH",
    body: JSON.stringify({ is_visible: isVisible }),
  });
  return res.data;
}

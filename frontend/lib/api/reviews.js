import { apiFetch } from "@/lib/api/client";

/** Only is_visible = true reviews are ever returned (Stage 8 §31/§32). */
export async function getProductReviews(productId, params = {}) {
  const res = await apiFetch(`/products/${productId}/reviews`, { params });
  return { items: res.data ?? [], meta: res.meta ?? { limit: 0, offset: 0, total: 0 } };
}

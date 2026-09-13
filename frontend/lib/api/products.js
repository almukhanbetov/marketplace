import { apiFetch } from "@/lib/api/client";

/**
 * params: { search, category, category_id, seller, brand, min_price,
 * max_price, rating, sort, limit, offset } — all optional, forwarded
 * verbatim to GET /products. Returns { items, meta } (meta has
 * limit/offset/total for pagination).
 */
export async function getProducts(params = {}) {
  const res = await apiFetch("/products", { params });
  return { items: res.data ?? [], meta: res.meta ?? { limit: 0, offset: 0, total: 0 } };
}

/** Returns the product detail, or null on a 404 (PRODUCT_NOT_FOUND). */
export async function getProduct(id) {
  const res = await apiFetch(`/products/${id}`);
  return res.data;
}

export async function getProductOffers(id) {
  const res = await apiFetch(`/products/${id}/offers`);
  return res.data ?? [];
}

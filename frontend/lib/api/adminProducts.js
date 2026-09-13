import { apiFetch } from "@/lib/api/client";

export async function getAdminProducts(params = {}) {
  const res = await apiFetch("/admin/products", { params });
  return { items: res.data ?? [], meta: res.meta ?? { limit: 0, offset: 0, total: 0 } };
}

export async function getAdminProduct(id) {
  const res = await apiFetch(`/admin/products/${id}`);
  return res.data;
}

/** Admin manages global catalog identity only — never seller price/stock
 * (Stage 8 §13/§53). images: [{url, is_primary, sort_order}]. */
export async function createAdminProduct(input) {
  const res = await apiFetch("/admin/products", { method: "POST", body: JSON.stringify(toProductBody(input)) });
  return res.data;
}

export async function updateAdminProduct(id, input) {
  const res = await apiFetch(`/admin/products/${id}`, { method: "PUT", body: JSON.stringify(toProductBody(input)) });
  return res.data;
}

export async function setAdminProductStatus(id, isActive) {
  const res = await apiFetch(`/admin/products/${id}/status`, {
    method: "PATCH",
    body: JSON.stringify({ is_active: isActive }),
  });
  return res.data;
}

function toProductBody(input) {
  return {
    category_id: input.categoryId,
    brand: input.brand || "",
    name_ru: input.nameRu,
    name_kk: input.nameKk,
    name_en: input.nameEn,
    description_ru: input.descriptionRu || "",
    description_kk: input.descriptionKk || "",
    description_en: input.descriptionEn || "",
    slug: input.slug,
    is_active: input.isActive,
    images: input.images,
  };
}

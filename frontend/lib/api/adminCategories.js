import { apiFetch } from "@/lib/api/client";

export async function getAdminCategories() {
  const res = await apiFetch("/admin/categories");
  return res.data ?? [];
}

function toCategoryBody(input) {
  return {
    parent_id: input.parentId || null,
    name_ru: input.nameRu,
    name_kk: input.nameKk,
    name_en: input.nameEn,
    slug: input.slug,
    image_url: input.imageUrl || "",
    sort_order: input.sortOrder || 0,
    is_active: input.isActive,
  };
}

export async function createAdminCategory(input) {
  const res = await apiFetch("/admin/categories", { method: "POST", body: JSON.stringify(toCategoryBody(input)) });
  return res.data;
}

export async function updateAdminCategory(id, input) {
  const res = await apiFetch(`/admin/categories/${id}`, { method: "PUT", body: JSON.stringify(toCategoryBody(input)) });
  return res.data;
}

export async function setAdminCategoryStatus(id, isActive) {
  const res = await apiFetch(`/admin/categories/${id}/status`, {
    method: "PATCH",
    body: JSON.stringify({ is_active: isActive }),
  });
  return res.data;
}

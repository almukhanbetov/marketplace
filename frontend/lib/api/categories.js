import { apiFetch } from "@/lib/api/client";

export async function getCategories() {
  const res = await apiFetch("/categories");
  return res.data ?? [];
}

export async function getCategory(id) {
  const res = await apiFetch(`/categories/${id}`);
  return res.data;
}

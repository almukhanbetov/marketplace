import { apiFetch } from "@/lib/api/client";

export async function getFavorites() {
  const res = await apiFetch("/me/favorites");
  return res.data ?? [];
}

export async function addFavorite(productId) {
  await apiFetch(`/me/favorites/${productId}`, { method: "POST" });
}

export async function removeFavorite(productId) {
  await apiFetch(`/me/favorites/${productId}`, { method: "DELETE" });
}

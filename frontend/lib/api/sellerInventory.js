import { apiFetch } from "@/lib/api/client";

export async function getSellerInventory() {
  const res = await apiFetch("/seller/inventory");
  return res.data ?? [];
}

export async function updateSellerInventory(offerId, availableQuantity) {
  const res = await apiFetch(`/seller/inventory/${offerId}`, {
    method: "PATCH",
    body: JSON.stringify({ available_quantity: availableQuantity }),
  });
  return res.data;
}

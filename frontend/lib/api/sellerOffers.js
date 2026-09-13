import { apiFetch } from "@/lib/api/client";

export async function getSellerOffers(params = {}) {
  const res = await apiFetch("/seller/offers", { params });
  return { items: res.data ?? [], meta: res.meta ?? { limit: 0, offset: 0, total: 0 } };
}

/** productId/sku/price/deliveryDays/stock are required; oldPrice is
 * optional. The seller picks an EXISTING catalog product — this never
 * creates a new product (Stage 7 §35). */
export async function createSellerOffer({ productId, sku, price, oldPrice, deliveryDays, stock }) {
  const res = await apiFetch("/seller/offers", {
    method: "POST",
    body: JSON.stringify({
      product_id: productId,
      sku,
      price,
      old_price: oldPrice || "",
      delivery_days: deliveryDays,
      stock,
    }),
  });
  return res.data;
}

export async function updateSellerOffer(offerId, { sku, price, oldPrice, deliveryDays }) {
  const res = await apiFetch(`/seller/offers/${offerId}`, {
    method: "PUT",
    body: JSON.stringify({ sku, price, old_price: oldPrice || "", delivery_days: deliveryDays }),
  });
  return res.data;
}

export async function setSellerOfferStatus(offerId, isActive) {
  const res = await apiFetch(`/seller/offers/${offerId}/status`, {
    method: "PATCH",
    body: JSON.stringify({ is_active: isActive }),
  });
  return res.data;
}

/**
 * Translates Go API JSON shapes into the legacy mock product/seller shape
 * that ProductCard, ProductGrid, ProductCarousel, ProductGallery,
 * ProductInfo, SellerOffers and CartContext already render — so those
 * components need no (or minimal) changes for Stage 4. Fields the backend
 * doesn't provide (colors, sizes, installment plans, seller follower
 * counts, ...) are filled with a safe absence (null/0) so existing
 * conditional rendering just skips them.
 */

const DELIVERY_OPTIONS = ["tomorrow", "today", "2days"];

/** Selects the localized string for the current language with a fallback
 * chain: requested lang -> ru -> en -> first non-empty value. */
export function getLocalizedValue(value, lang) {
  if (!value) return "";
  return value[lang] || value.ru || value.en || Object.values(value).find(Boolean) || "";
}

/** Parses a backend decimal-string money value into a Number for display
 * (toLocaleString formatting) only — never used for further money math
 * beyond the same display-total arithmetic the legacy mock cart already
 * did with plain numbers. */
export function parseMoney(value) {
  if (value === null || value === undefined) return 0;
  const n = typeof value === "string" ? Number(value) : value;
  return Number.isFinite(n) ? n : 0;
}

function deliveryDaysToCode(days) {
  if (days === 0) return "today";
  if (days === 1) return "tomorrow";
  return "2days";
}

/** GET /products list item -> legacy ProductCard shape. */
export function adaptProductCard(p, lang) {
  const price = parseMoney(p.price);
  return {
    id: p.id,
    slug: p.slug,
    title: getLocalizedValue(p.name, lang),
    brand: p.brand,
    category: p.category?.slug,
    rating: p.rating,
    reviews: p.review_count,
    image: p.primary_image || null,
    image2: p.primary_image || null,
    price,
    oldPrice: p.old_price ? parseMoney(p.old_price) : price,
    discount: p.discount_percent || 0,
    badge: p.discount_percent >= 20 ? "sale" : null,
    seller: p.seller_name || "",
    sellerId: null,
    sellerRating: p.seller_rating ?? null,
    sellerCount: p.seller_count,
    sellerOfferId: p.best_offer_id ?? null,
    delivery: deliveryDaysToCode(p.min_delivery_days),
    installment: Math.round(price / 24),
    flashSale: false,
    flashSoldPct: 0,
    colors: null,
    sizes: null,
  };
}

/** GET /products/:id detail -> legacy ProductPageContent/ProductInfo shape,
 * priced from the product's best_offer (cheapest valid offer). */
export function adaptProductDetail(p, lang) {
  const best = p.best_offer;
  const price = best ? parseMoney(best.price) : 0;
  const images = p.images && p.images.length ? p.images : [];
  return {
    id: p.id,
    slug: p.slug,
    title: getLocalizedValue(p.name, lang),
    brand: p.brand,
    category: p.category?.slug,
    categoryName: getLocalizedValue(p.category?.name, lang),
    description: getLocalizedValue(p.description, lang),
    rating: p.rating,
    reviews: p.review_count,
    image: images[0] || null,
    image2: images[1] || images[0] || null,
    images,
    price,
    oldPrice: best?.old_price ? parseMoney(best.old_price) : price,
    discount: best?.discount_percent || 0,
    seller: best?.seller_name || "",
    sellerId: best?.seller_id ?? null,
    sellerSlug: best?.seller_slug || null,
    sellerRating: best?.seller_rating ?? null,
    sellerCount: p.seller_count,
    delivery: deliveryDaysToCode(best?.delivery_days ?? 2),
    installment: Math.round(price / 24),
    sellerOfferId: best?.offer_id ?? null,
    availableQuantity: best?.available_quantity ?? 0,
    hasOffers: !!best,
    colors: null,
    sizes: null,
  };
}

/** GET /products/:id/offers item -> legacy SellerOffers row shape. */
export function adaptOffer(o) {
  return {
    offerId: o.offer_id,
    seller: o.seller_name,
    sellerId: o.seller_id,
    sellerSlug: o.seller_slug,
    rating: o.seller_rating,
    verified: o.seller_verified,
    delivery: deliveryDaysToCode(o.delivery_days),
    price: parseMoney(o.price),
    oldPrice: o.old_price ? parseMoney(o.old_price) : parseMoney(o.price),
  };
}

/** GET /sellers list item -> a compact shape for filter facets. */
export function adaptSellerListItem(s) {
  return {
    id: s.id,
    name: s.name,
    slug: s.slug,
    rating: s.rating,
    reviewCount: s.review_count,
    isVerified: s.is_verified,
    activeOfferCount: s.active_offer_count,
  };
}

/** GET /sellers/:id -> the fields SellerPageContent's hero actually has
 * available (the mock's positive%/sales/years/followers have no backend
 * equivalent and are intentionally dropped, not faked). */
export function adaptSellerDetail(s) {
  return {
    id: s.id,
    name: s.name,
    slug: s.slug,
    description: s.description,
    rating: s.rating,
    reviewCount: s.review_count,
    isVerified: s.is_verified,
    isActive: s.is_active,
    productCount: s.product_count,
    activeOfferCount: s.active_offer_count,
  };
}

/** GET /sellers/:id/products item -> legacy ProductCard shape, priced at
 * THIS seller's own offer (not the marketplace-wide cheapest). */
export function adaptSellerProductItem(item, seller, lang) {
  const price = parseMoney(item.price);
  return {
    id: item.product_id,
    slug: item.slug,
    title: getLocalizedValue(item.name, lang),
    brand: item.brand,
    rating: item.rating,
    reviews: item.review_count,
    image: item.primary_image || null,
    image2: item.primary_image || null,
    price,
    oldPrice: item.old_price ? parseMoney(item.old_price) : price,
    discount: item.discount_percent || 0,
    badge: item.discount_percent >= 20 ? "sale" : null,
    seller: seller?.name || "",
    sellerId: seller?.id ?? null,
    sellerRating: seller?.rating ?? null,
    sellerOfferId: item.offer_id,
    delivery: deliveryDaysToCode(item.delivery_days),
    installment: Math.round(price / 24),
    flashSale: false,
    flashSoldPct: 0,
    colors: null,
    sizes: null,
  };
}

/**
 * GET/POST/PATCH/DELETE .../cart item -> legacy cart-line shape. `id` here
 * is the CART ITEM id (needed for PATCH/DELETE — Stage 5's cart is keyed
 * by seller_offer_id, not product_id, so two lines can share a product),
 * never the product id — callers that need the product id read
 * `item.product.id` explicitly.
 */
export function adaptCartItem(item, lang) {
  const price = parseMoney(item.price);
  return {
    id: item.id,
    qty: item.quantity,
    sellerOfferId: item.seller_offer_id,
    isAvailable: item.is_available,
    availableQuantity: item.available_quantity,
    product: {
      id: item.product.id,
      title: getLocalizedValue(item.product.name, lang),
      brand: item.product.brand,
      image: item.product.primary_image || null,
      price,
      oldPrice: item.old_price ? parseMoney(item.old_price) : price,
      seller: item.seller.name,
      sellerId: item.seller.id,
      sellerRating: item.seller.rating,
    },
    lineTotal: parseMoney(item.line_total),
  };
}

/** GET .../cart -> { items, summary } using adaptCartItem for each line. */
export function adaptCart(cart, lang) {
  const items = (cart?.items || []).map((i) => adaptCartItem(i, lang));
  return {
    id: cart?.id ?? null,
    items,
    itemCount: cart?.summary?.item_count ?? 0,
    subtotal: parseMoney(cart?.summary?.subtotal),
  };
}

export { DELIVERY_OPTIONS };

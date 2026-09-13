"use client";

import Link from "next/link";
import { useLanguage } from "@/context/LanguageContext";
import { useCart } from "@/context/CartContext";
import { useFavorites } from "@/context/FavoritesContext";
import { useCompare } from "@/context/CompareContext";
import { useModal } from "@/context/ModalContext";
import { useToast } from "@/context/NotificationContext";
import { formatPrice } from "@/lib/currency";
import { deliveryLabel } from "@/lib/helpers";

export default function ProductCard({ product: p, showStockBar = false }) {
  const { t, lang } = useLanguage();
  const cart = useCart();
  const favorites = useFavorites();
  const compare = useCompare();
  const { openModal } = useModal();
  const { showToast } = useToast();

  const cartItem = p.sellerOfferId != null ? cart.getItemByOffer(p.sellerOfferId) : cart.items.find((i) => i.product.id === p.id);
  const inCart = !!cartItem;
  const isFav = favorites.isFavorite(p.id);

  async function handleAddToCart(e) {
    e.preventDefault();
    await cart.addToCart(p, 1);
  }

  async function handleToggleFav(e) {
    e.preventDefault();
    try {
      const added = await favorites.toggleFavorite(p);
      showToast(added ? t("addedToFav") : t("removedFromFav"), added ? "success" : "info", added ? "♡" : "✕");
    } catch {
      showToast(lang === "en" ? "Couldn't update favorites." : "Не удалось обновить избранное.", "warn", "⚠");
    }
  }

  function handleQuickView(e) {
    e.preventDefault();
    openModal("quickview", { productId: p.id });
  }

  function handleToggleCompare(e) {
    e.preventDefault();
    const result = compare.toggleCompare(p.id);
    if (result === "removed") showToast("Удалено из сравнения", "info", "✕");
    else if (result === "full") showToast("Можно сравнить максимум 4 товара", "warn", "⚠");
    else showToast("Добавлено к сравнению", "success", "✓");
  }

  return (
    <article className="product-card">
      <Link href={`/product/${p.id}`} className="pc-media" aria-label={p.title}>
        <div className="pc-badges">
          {p.badge === "sale" && <span className="badge badge--sale">−{p.discount}%</span>}
          {p.badge === "new" && <span className="badge badge--new">{t("newArrivals").split(" ")[0]}</span>}
        </div>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img className="primary" src={p.image} alt={p.title} loading="lazy" />
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img className="secondary" src={p.image2} alt="" loading="lazy" />
      </Link>

      <button
        className={`pc-fav ${isFav ? "active" : ""}`}
        onClick={handleToggleFav}
        aria-label="Favorite"
        aria-pressed={isFav}
      >
        {isFav ? "♥" : "♡"}
      </button>

      <div className="pc-quick">
        <button onClick={handleQuickView}>{t("quickView")}</button>
        <button onClick={handleToggleCompare}>{t("compare")}</button>
      </div>

      <div className="pc-body">
        <div className="pc-rating">
          <span className="stars">★★★★★</span>
          <b>{p.rating}</b>&middot; {p.reviews} {t("reviews")}
        </div>
        <div className="pc-brand">{p.brand}</div>
        <Link href={`/product/${p.id}`} className="pc-title">
          {p.title}
        </Link>
        <div className="pc-price-row">
          <span className="pc-price">{formatPrice(p.price)}</span>
          <span className="pc-price-old">{formatPrice(p.oldPrice)}</span>
          <span className="pc-discount">−{p.discount}%</span>
        </div>
        <div className="pc-installment">
          {t("from")} <b>{formatPrice(p.installment)}</b> × 24
        </div>
        <div className="pc-delivery">🚚 {deliveryLabel(p.delivery, t, lang)}</div>
        <div className="pc-seller">
          <span>
            {t("sellerLabel")}: <b>{p.seller}</b>
          </span>
          <span className="stars">★{p.sellerRating}</span>
        </div>

        {showStockBar && p.flashSale && (
          <div className="pc-stock-bar">
            <div className="stock-bar-track">
              <div className="stock-bar-fill" style={{ width: `${p.flashSoldPct}%` }} />
            </div>
            <div className="stock-bar-label">Продано {p.flashSoldPct}%</div>
          </div>
        )}

        {!inCart && (
          <button className="pc-cart-btn" onClick={handleAddToCart}>
            🛒 {t("addToCart")}
          </button>
        )}
        {inCart && (
          <div className="pc-qty show">
            <button onClick={() => cart.decreaseQuantity(p.id)}>−</button>
            <span>{cartItem?.qty ?? 1}</span>
            <button onClick={() => cart.increaseQuantity(p.id)}>+</button>
          </div>
        )}
      </div>
    </article>
  );
}

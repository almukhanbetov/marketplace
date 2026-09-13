"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useLanguage } from "@/context/LanguageContext";
import { useCart } from "@/context/CartContext";
import { useFavorites } from "@/context/FavoritesContext";
import { useToast } from "@/context/NotificationContext";
import { formatPrice } from "@/lib/currency";
import { deliveryLabel } from "@/lib/helpers";

export default function ProductInfo({ product, questionsCount }) {
  const { t, lang } = useLanguage();
  const router = useRouter();
  const cart = useCart();
  const favorites = useFavorites();
  const { showToast } = useToast();

  const [selectedColor, setSelectedColor] = useState(product.colors?.[0] ?? null);
  const [selectedSize, setSelectedSize] = useState(product.sizes?.[0] ?? null);
  const [qty, setQty] = useState(1);

  const isFav = favorites.isFavorite(product.id);

  async function handleAddToCart() {
    await cart.addToCart(product, qty);
  }

  async function handleBuyNow() {
    await cart.addToCart(product, qty);
    router.push("/checkout");
  }

  async function handleToggleFav() {
    try {
      const added = await favorites.toggleFavorite(product);
      showToast(added ? t("addedToFav") : t("removedFromFav"), added ? "success" : "info", added ? "♡" : "✕");
    } catch {
      showToast(lang === "en" ? "Couldn't update favorites." : "Не удалось обновить избранное.", "warn", "⚠");
    }
  }

  return (
    <>
      <div>
        <div className="pc-brand">{product.brand}</div>
        <h1 style={{ fontSize: "var(--fs-2xl)", fontWeight: 800, margin: "6px 0 10px", lineHeight: 1.15 }}>
          {product.title}
        </h1>
        <div className="pc-rating" style={{ fontSize: "var(--fs-sm)", marginBottom: 16 }}>
          <span className="stars">★★★★★</span>
          <b>{product.rating}</b> &middot; {product.reviews} {t("reviews")}
        </div>

        {product.colors && (
          <div style={{ marginBottom: 18 }}>
            <div className="eyebrow" style={{ marginBottom: 8 }}>
              {t("color")}
            </div>
            <div className="color-swatch-row">
              {product.colors.map((c) => (
                <button
                  key={c}
                  className={`color-swatch ${c === selectedColor ? "active" : ""}`}
                  style={{ background: c }}
                  aria-label={`Цвет ${c}`}
                  onClick={() => setSelectedColor(c)}
                />
              ))}
            </div>
          </div>
        )}

        {product.sizes && (
          <div style={{ marginBottom: 18 }}>
            <div className="eyebrow" style={{ marginBottom: 8 }}>
              {t("size")}
            </div>
            <div style={{ display: "flex", gap: 8 }}>
              {product.sizes.map((s) => (
                <button
                  key={s}
                  className={`btn btn--sm ${s === selectedSize ? "btn--primary" : "btn--outline"}`}
                  onClick={() => setSelectedSize(s)}
                >
                  {s}
                </button>
              ))}
            </div>
          </div>
        )}

        <div style={{ marginBottom: 18 }}>
          <div className="eyebrow" style={{ marginBottom: 8 }}>
            {t("productQuestions")}
          </div>
          <div style={{ fontSize: "var(--fs-xs)", color: "var(--text-2)" }}>
            {questionsCount} {lang === "en" ? "questions answered" : "вопроса с ответами"}
          </div>
        </div>
      </div>

      <div>
        <div className="info-card">
          <div className="pc-price-row" style={{ marginBottom: 6 }}>
            <span className="pc-price" style={{ fontSize: "var(--fs-2xl)" }}>
              {formatPrice(product.price)}
            </span>
          </div>
          <div style={{ display: "flex", gap: 8, alignItems: "center", marginBottom: 10 }}>
            <span className="pc-price-old">{formatPrice(product.oldPrice)}</span>
            <span className="badge badge--sale">−{product.discount}%</span>
          </div>
          <div className="pc-installment" style={{ marginBottom: 14 }}>
            {t("from")} <b>{formatPrice(product.installment)}</b> × 24 {t("installmentSuffix")}
          </div>

          <div className="pc-delivery" style={{ marginBottom: 6 }}>
            🚚 {deliveryLabel(product.delivery, t, lang)}, {t("free")}
          </div>
          <div className="pc-seller" style={{ border: "none", paddingTop: 6 }}>
            <span>
              {t("sellerLabel")}:{" "}
              <Link href={`/seller/${product.sellerId}`}>
                <b>{product.seller}</b>
              </Link>
            </span>
            <span className="stars">★{product.sellerRating}</span>
          </div>

          <div style={{ display: "flex", alignItems: "center", gap: 10, margin: "16px 0" }}>
            <span style={{ fontSize: "var(--fs-xs)", color: "var(--text-2)" }}>{t("quantity")}</span>
            <div className="qty-stepper">
              <button onClick={() => setQty((q) => Math.max(1, q - 1))}>−</button>
              <span>{qty}</span>
              <button onClick={() => setQty((q) => q + 1)}>+</button>
            </div>
          </div>

          <button className="btn btn--accent btn--lg btn--block" style={{ marginBottom: 10 }} onClick={handleBuyNow}>
            {t("buyNow")}
          </button>
          <button className="btn btn--primary btn--lg btn--block" onClick={handleAddToCart}>
            🛒 {t("addToCart")}
          </button>
          <button
            className={`btn btn--outline btn--lg btn--block ${isFav ? "btn--danger" : ""}`}
            style={{ marginTop: 10 }}
            onClick={handleToggleFav}
          >
            {isFav ? "♥" : "♡"} {t("favorites")}
          </button>
        </div>
      </div>
    </>
  );
}

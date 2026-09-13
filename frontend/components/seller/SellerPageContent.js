"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useLanguage } from "@/context/LanguageContext";
import { adaptSellerDetail, adaptSellerProductItem } from "@/lib/api/adapters";
import ProductGrid from "@/components/product/ProductGrid";

const TABS = [
  { key: "products", label: "Товары" },
  { key: "promo", label: "Акции" },
  { key: "reviews", labelKey: "reviews" },
  { key: "about", label: "О продавце" },
];

const MOCK_SELLER_REVIEWS = [
  { name: "Нурлан Б.", text: "Быстрая доставка, товар как на фото. Спасибо!" },
  { name: "Салтанат Р.", text: "Отличный продавец, всегда на связи." },
];

export default function SellerPageContent({ seller: rawSeller, rawProducts }) {
  const { t, lang } = useLanguage();
  const [tab, setTab] = useState("products");
  const [following, setFollowing] = useState(false);

  const seller = useMemo(() => adaptSellerDetail(rawSeller), [rawSeller]);
  const gridProducts = useMemo(
    () => (rawProducts || []).map((item) => adaptSellerProductItem(item, seller, lang)),
    [rawProducts, seller, lang]
  );
  const dist = [82, 11, 4, 2, 1];

  return (
    <>
      <div className="container page-section--tight">
        <nav className="breadcrumbs" aria-label="Breadcrumb">
          <Link href="/">{t("home")}</Link>
          <span aria-hidden="true">/</span>
          <span>{seller.name}</span>
        </nav>

        <div className="seller-hero">
          <div className="seller-logo">{seller.name.slice(0, 2).toUpperCase()}</div>
          <div style={{ flex: 1, minWidth: 220 }}>
            <h1 style={{ fontSize: "var(--fs-xl)", fontWeight: 800 }}>{seller.name}</h1>
            <div className="seller-meta-row">
              <span>★ <b>{seller.rating}</b></span>
              <span><b>{seller.reviewCount.toLocaleString("ru-RU")}</b> {t("reviews")}</span>
              <span><b>{seller.productCount.toLocaleString("ru-RU")}</b> {lang === "en" ? "products" : "товаров"}</span>
              <span><b>{seller.activeOfferCount.toLocaleString("ru-RU")}</b> {lang === "en" ? "active offers" : "активных предложений"}</span>
              {seller.isVerified && <span>✓ {lang === "en" ? "Verified seller" : "Проверенный продавец"}</span>}
            </div>
          </div>
          <button
            className={`btn btn--lg ${following ? "btn--secondary" : "btn--primary"}`}
            onClick={() => setFollowing((v) => !v)}
          >
            {following ? "✓ Вы подписаны" : "+ Подписаться"}
          </button>
        </div>
      </div>

      <div className="container page-section">
        <div className="tab-row">
          {TABS.map((tb) => (
            <button key={tb.key} className={`tab-btn ${tab === tb.key ? "active" : ""}`} onClick={() => setTab(tb.key)}>
              {tb.labelKey ? t(tb.labelKey) : tb.label}
            </button>
          ))}
        </div>

        {tab === "products" && (
          <div className="tab-panel active">
            <ProductGrid products={gridProducts} />
          </div>
        )}

        {tab === "promo" && (
          <div className="tab-panel active">
            <div className="hero-promos" style={{ display: "grid", gridTemplateColumns: "repeat(2,1fr)", gap: 18 }}>
              <div className="promo-card promo-card--a"><b>Скидка 15% на всё</b><span>При заказе от 3 товаров</span></div>
              <div className="promo-card promo-card--b"><b>Бесплатная доставка</b><span>При заказе от 50 000 ₸</span></div>
            </div>
          </div>
        )}

        {tab === "reviews" && (
          <div className="tab-panel active">
            <div className="review-summary">
              <div className="review-score">
                <div className="big">{seller.rating}</div>
                <div className="stars">★★★★★</div>
              </div>
              <div className="review-bars">
                {dist.map((pct, i) => (
                  <div className="review-bar-row" key={i}>
                    <span>{5 - i} ★</span>
                    <div className="track"><div className="fill" style={{ width: `${pct}%` }} /></div>
                    <span>{pct}%</span>
                  </div>
                ))}
              </div>
            </div>
            <div style={{ marginTop: 24 }}>
              {MOCK_SELLER_REVIEWS.map((r, i) => (
                <div className="review-card" key={i}>
                  <div className="review-avatar">{r.name.charAt(0)}</div>
                  <div>
                    <div className="review-name">{r.name}</div>
                    <div className="review-text">{r.text}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {tab === "about" && (
          <div className="tab-panel active">
            <div className="info-card">
              <p style={{ lineHeight: 1.7, color: "var(--text-2)" }}>
                Официальный продавец на платформе Nova с широким ассортиментом качественных товаров.
                Быстрая доставка по всему Казахстану, гарантия на все товары и поддержка 24/7.
              </p>
            </div>
          </div>
        )}
      </div>
    </>
  );
}

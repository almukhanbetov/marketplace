"use client";

import Link from "next/link";
import { useLanguage } from "@/context/LanguageContext";
import { useFavorites } from "@/context/FavoritesContext";
import ProductGrid from "@/components/product/ProductGrid";

export default function FavoritesPage() {
  const { t } = useLanguage();
  const favorites = useFavorites();
  const items = favorites.items;

  return (
    <div className="container page-section--tight">
      <nav className="breadcrumbs" aria-label="Breadcrumb">
        <Link href="/">{t("home")}</Link>
        <span aria-hidden="true">/</span>
        <span>{t("favorites")}</span>
      </nav>
      <div className="section-head">
        <h1 style={{ fontSize: "var(--fs-xl)", fontWeight: 800 }}>{t("favorites")}</h1>
      </div>

      {!items.length ? (
        <div className="empty-state">
          <div className="empty-state__icon">♡</div>
          <h3>{t("favorites")}: 0</h3>
          <p>Добавляйте товары в избранное, нажимая на сердечко на карточке товара.</p>
          <Link href="/catalog" className="btn btn--primary btn--lg" style={{ marginTop: 10 }}>
            {t("startShopping")}
          </Link>
        </div>
      ) : (
        <ProductGrid products={items} />
      )}
    </div>
  );
}

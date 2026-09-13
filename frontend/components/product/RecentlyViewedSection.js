"use client";

import { useLanguage } from "@/context/LanguageContext";
import { useRecentlyViewed } from "@/lib/useRecentlyViewed";
import ProductGrid from "@/components/product/ProductGrid";

export default function RecentlyViewedSection() {
  const { t } = useLanguage();
  const { items } = useRecentlyViewed();

  if (!items.length) return null;

  return (
    <section className="page-section container">
      <div className="section-head">
        <h2>{t("recentlyViewed")}</h2>
      </div>
      <ProductGrid products={items} />
    </section>
  );
}

"use client";

import { useLayoutEffect, useMemo } from "react";
import Link from "next/link";
import { useLanguage } from "@/context/LanguageContext";
import { adaptOffer, adaptProductDetail } from "@/lib/api/adapters";
import ProductGallery from "@/components/product/ProductGallery";
import ProductInfo from "@/components/product/ProductInfo";
import SellerOffers from "@/components/product/SellerOffers";
import ProductTabs, { MOCK_QUESTIONS } from "@/components/product/ProductTabs";
import RecentlyViewedSection from "@/components/product/RecentlyViewedSection";
import RecommendationsSection from "@/components/product/RecommendationsSection";
import { addRecentlyViewed } from "@/lib/useRecentlyViewed";

export default function ProductPageContent({ product: rawProduct, rawOffers }) {
  const { t, lang } = useLanguage();
  const product = useMemo(() => adaptProductDetail(rawProduct, lang), [rawProduct, lang]);
  const offers = useMemo(() => (rawOffers || []).map(adaptOffer), [rawOffers]);

  // useLayoutEffect (not useEffect) so this commits before the child
  // RecentlyViewedSection's own effect reads localStorage — matching the
  // legacy behaviour where the current product appears in its own
  // "recently viewed" row.
  useLayoutEffect(() => {
    addRecentlyViewed(product.id);
  }, [product.id]);

  return (
    <>
      <div className="container page-section--tight">
        <nav className="breadcrumbs" aria-label="Breadcrumb">
          <Link href="/">{t("home")}</Link>
          <span aria-hidden="true">/</span>
          <Link href={`/catalog?cat=${product.category}`}>{product.categoryName || product.category}</Link>
          <span aria-hidden="true">/</span>
          <span>{product.title}</span>
        </nav>
      </div>

      <div className="container page-section--tight">
        <div
          id="pdp-root"
          style={{ display: "grid", gridTemplateColumns: "460px 1fr 340px", gap: 30, alignItems: "start" }}
        >
          <ProductGallery product={product} />
          <ProductInfo product={product} questionsCount={MOCK_QUESTIONS.length} />
        </div>
      </div>

      <div className="container page-section">
        <div className="section-head">
          <h2>{t("otherSellers")}</h2>
        </div>
        <SellerOffers offers={offers} />
      </div>

      <div className="container page-section">
        <ProductTabs product={product} />
      </div>

      <RecentlyViewedSection />
      <RecommendationsSection />
    </>
  );
}

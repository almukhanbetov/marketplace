"use client";

import { useMemo } from "react";
import Link from "next/link";
import { useLanguage } from "@/context/LanguageContext";
import { adaptProductCard } from "@/lib/api/adapters";
import HeroSlider from "@/components/home/HeroSlider";
import CategoryGrid from "@/components/home/CategoryGrid";
import FlashSale from "@/components/home/FlashSale";
import ProductGrid from "@/components/product/ProductGrid";
import ProductCarousel from "@/components/product/ProductCarousel";
import RecentlyViewedSection from "@/components/product/RecentlyViewedSection";
import RecommendationsSection from "@/components/product/RecommendationsSection";

export default function HomeContent({ forYou, bestSellers, onSale, newArrivals }) {
  const { t, lang } = useLanguage();

  const forYouAdapted = useMemo(() => forYou.map((p) => adaptProductCard(p, lang)), [forYou, lang]);
  const bestSellersAdapted = useMemo(() => bestSellers.map((p) => adaptProductCard(p, lang)), [bestSellers, lang]);
  const onSaleAdapted = useMemo(() => onSale.map((p) => adaptProductCard(p, lang)), [onSale, lang]);
  const newArrivalsAdapted = useMemo(() => newArrivals.map((p) => adaptProductCard(p, lang)), [newArrivals, lang]);

  return (
    <>
      <section className="page-section page-section--tight container">
        <HeroSlider />
      </section>

      <section className="page-section container">
        <div className="section-head">
          <h2>{t("categoriesTitle")}</h2>
        </div>
        <CategoryGrid />
      </section>

      <section className="page-section container">
        <FlashSale />
      </section>

      <section className="page-section container">
        <div className="section-head">
          <div>
            <h2>{t("forYou")}</h2>
            <div className="section-sub">Персональная подборка на основе ваших интересов</div>
          </div>
          <Link href="/catalog" className="btn btn--ghost">
            {t("viewAll")}
          </Link>
        </div>
        <ProductGrid products={forYouAdapted} />
      </section>

      <section className="page-section container">
        <div className="section-head">
          <h2>{t("bestSellers")}</h2>
          <Link href="/catalog?sort=popular" className="btn btn--ghost">
            {t("viewAll")}
          </Link>
        </div>
        <ProductCarousel products={bestSellersAdapted} />
      </section>

      <section className="page-section container">
        <div className="section-head">
          <h2>{t("onSaleNow")}</h2>
          <Link href="/catalog?sort=discount" className="btn btn--ghost">
            {t("viewAll")}
          </Link>
        </div>
        <ProductGrid products={onSaleAdapted} />
      </section>

      <section className="page-section container">
        <div className="section-head">
          <h2>{t("newArrivals")}</h2>
          <Link href="/catalog?sort=new" className="btn btn--ghost">
            {t("viewAll")}
          </Link>
        </div>
        <ProductCarousel products={newArrivalsAdapted} />
      </section>

      <RecentlyViewedSection />
      <RecommendationsSection />
    </>
  );
}

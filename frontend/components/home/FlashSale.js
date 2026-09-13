"use client";

import Link from "next/link";
import { useLanguage } from "@/context/LanguageContext";
import { useCountdown } from "@/lib/useCountdown";
import { products } from "@/data/products";
import ProductCarousel from "@/components/product/ProductCarousel";

export default function FlashSale() {
  const { t } = useLanguage();
  const time = useCountdown();
  const flashProducts = products.filter((p) => p.flashSale);

  return (
    <div className="flash-sale">
      <div className="flash-head">
        <div className="flash-title">
          <span className="flash-icon">⚡</span>
          <span>{t("flashSale")}</span>
        </div>
        <div className="flash-timer">
          <span className="unit">{time.h}</span>
          <span className="colon">:</span>
          <span className="unit">{time.m}</span>
          <span className="colon">:</span>
          <span className="unit">{time.s}</span>
        </div>
        <Link href="/catalog?sort=discount" className="btn btn--accent flash-cta">
          {t("viewAll")}
        </Link>
      </div>
      <ProductCarousel products={flashProducts} showStockBar />
    </div>
  );
}

"use client";

import { useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { useFavorites } from "@/context/FavoritesContext";
import { getProducts } from "@/lib/api/products";
import { adaptProductCard } from "@/lib/api/adapters";
import ProductGrid from "@/components/product/ProductGrid";

/** Approximates "recommended for you" with a real API query: top-rated
 * products in the same category as the user's most recent favorite, or a
 * generic top-rated list before any favorites exist. There's no dedicated
 * recommendations endpoint (and Stage 4/5 don't ask for one), so this
 * reuses the public catalog list exactly as the catalog page does. */
export default function RecommendationsSection() {
  const { t, lang } = useLanguage();
  const favorites = useFavorites();
  const [items, setItems] = useState([]);

  const seedCategory = favorites.items[0]?.category;

  useEffect(() => {
    let cancelled = false;
    getProducts({ category: seedCategory || undefined, limit: 6, sort: "rating_desc" })
      .then(({ items: raw }) => {
        if (!cancelled) setItems(raw.map((p) => adaptProductCard(p, lang)));
      })
      .catch(() => {
        if (!cancelled) setItems([]);
      });
    return () => {
      cancelled = true;
    };
  }, [seedCategory, lang]);

  return (
    <section className="page-section container">
      <div className="section-head">
        <h2>{t("mayLike")}</h2>
      </div>
      <ProductGrid products={items} />
    </section>
  );
}

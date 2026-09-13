"use client";

import { useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { getProduct } from "@/lib/api/products";
import { adaptProductDetail } from "@/lib/api/adapters";

/**
 * Resolves a list of product ids against the real backend (Stage 5: these
 * ids increasingly end up in cart/favorite operations that need a real
 * seller_offer_id, which a mock product object never has). Used by
 * recently-viewed and compare, whose own id lists still live in
 * localStorage (Stage 5 §40 only requires favorites/cart/addresses to drop
 * localStorage, not every id-list feature) — only the product data behind
 * each id is now real.
 */
export function useProductsByIds(ids) {
  const { lang } = useLanguage();
  const [items, setItems] = useState([]);
  const key = ids.join(",");

  useEffect(() => {
    if (!ids.length) {
      setItems([]);
      return;
    }
    let cancelled = false;
    Promise.all(
      ids.map((id) =>
        getProduct(id)
          .then((p) => adaptProductDetail(p, lang))
          .catch(() => null)
      )
    ).then((results) => {
      if (!cancelled) setItems(results.filter(Boolean));
    });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, lang]);

  return items;
}

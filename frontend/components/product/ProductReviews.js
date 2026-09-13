"use client";

import { useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { getProductReviews } from "@/lib/api/reviews";

/** Stage 8 §31/§32: real reviews from GET /products/:id/reviews — only
 * is_visible=true rows ever reach here. No fabricated "helpful" counter or
 * rating-distribution bars (the backend has neither concept); those were
 * a Stage 4 mock and are dropped rather than wired to fake data. */
export default function ProductReviews({ product }) {
  const { t, lang } = useLanguage();
  const [reviews, setReviews] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!product?.id) return;
    let cancelled = false;
    getProductReviews(product.id, { limit: 20 })
      .then(({ items }) => {
        if (!cancelled) setReviews(items);
      })
      .catch(() => {
        if (!cancelled) setReviews([]);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [product?.id]);

  return (
    <div>
      <div className="review-summary">
        <div className="review-score">
          <div className="big">{product.rating}</div>
          <div className="stars">★★★★★</div>
          <div className="text-muted" style={{ fontSize: "var(--fs-xs)", marginTop: 4 }}>
            {product.reviews} {t("reviews")}
          </div>
        </div>
      </div>

      <div style={{ marginTop: 24 }}>
        {loading ? null : !reviews.length ? (
          <div className="text-muted">{lang === "en" ? "No reviews yet." : "Пока нет отзывов."}</div>
        ) : (
          reviews.map((r) => (
            <div className="review-card" key={r.id}>
              <div className="review-avatar">{r.user_display_name.charAt(0)}</div>
              <div style={{ flex: 1 }}>
                <div className="review-head">
                  <span className="review-name">{r.user_display_name}</span>
                  <span className="stars">
                    {"★".repeat(r.rating)}
                    {"☆".repeat(5 - r.rating)}
                  </span>
                  <span className="review-date">{new Date(r.created_at).toLocaleDateString(lang === "en" ? "en-US" : "ru-RU")}</span>
                </div>
                <div className="review-text">{r.text}</div>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

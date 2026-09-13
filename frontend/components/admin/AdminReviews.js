"use client";

import { useCallback, useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";
import { getAdminReviews, setAdminReviewVisibility } from "@/lib/api/adminReviews";

/** Stage 8 §33/§34/§61: real review moderation — hiding/showing never
 * physically deletes a review; the backend recalculates the product's
 * rating/review_count transactionally on every visibility change. */
export default function AdminReviews() {
  const { lang } = useLanguage();
  const { showToast } = useToast();
  const [reviews, setReviews] = useState([]);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(() => {
    return getAdminReviews({ limit: 100 })
      .then(({ items }) => setReviews(items))
      .catch(() => setReviews([]));
  }, []);

  useEffect(() => {
    setLoading(true);
    refresh().finally(() => setLoading(false));
  }, [refresh]);

  async function toggleVisibility(r) {
    try {
      await setAdminReviewVisibility(r.id, !r.is_visible);
      showToast(
        r.is_visible ? (lang === "en" ? "Review hidden" : "Отзыв скрыт") : (lang === "en" ? "Review shown" : "Отзыв показан"),
        "info",
        r.is_visible ? "⏸" : "✓"
      );
      await refresh();
    } catch (err) {
      showToast(err?.message || (lang === "en" ? "Couldn't update visibility." : "Не удалось изменить видимость."), "warn", "⚠");
    }
  }

  if (loading) return null;

  return (
    <div>
      {!reviews.length ? (
        <div className="empty-state">
          <div className="empty-state__icon">⭐</div>
          <h3>{lang === "en" ? "No reviews yet" : "Пока нет отзывов"}</h3>
        </div>
      ) : (
        reviews.map((r) => (
          <div className="review-card" key={r.id} style={{ opacity: r.is_visible ? 1 : 0.55 }}>
            <div className="review-avatar">{r.user_name.charAt(0)}</div>
            <div style={{ flex: 1 }}>
              <div className="review-head">
                <span className="review-name">{r.user_name}</span>
                <span className="stars">{"★".repeat(r.rating)}{"☆".repeat(5 - r.rating)}</span>
                <span className="review-date">{new Date(r.created_at).toLocaleDateString(lang === "en" ? "en-US" : "ru-RU")}</span>
              </div>
              <div className="text-muted" style={{ fontSize: "var(--fs-xs)", marginBottom: 4 }}>{r.product_name}</div>
              <div className="review-text">{r.text || "—"}</div>
              <div style={{ display: "flex", alignItems: "center", gap: 10, marginTop: 8 }}>
                <span className={`status-pill ${r.is_visible ? "status-pill--done" : "status-pill--cancel"}`}>
                  {r.is_visible ? (lang === "en" ? "Visible" : "Виден") : (lang === "en" ? "Hidden" : "Скрыт")}
                </span>
                <button className="btn btn--outline btn--sm" onClick={() => toggleVisibility(r)}>
                  {r.is_visible ? (lang === "en" ? "Hide" : "Скрыть") : (lang === "en" ? "Show" : "Показать")}
                </button>
              </div>
            </div>
          </div>
        ))
      )}
    </div>
  );
}

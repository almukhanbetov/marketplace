"use client";

import { useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { getSellerDashboard } from "@/lib/api/sellerDashboard";
import { formatPrice } from "@/lib/currency";

/** Stage 7: every card here maps 1:1 to a real field from
 * GET /sellers/:id/dashboard — no fabricated weekly chart or category
 * breakdown (the backend doesn't compute either), unlike the Stage 4 mock
 * this replaces. */
export default function SellerStats() {
  const { lang } = useLanguage();
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    getSellerDashboard()
      .then((data) => {
        if (!cancelled) setSummary(data);
      })
      .catch(() => {
        if (!cancelled) setSummary(null);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  if (loading) return null;

  if (!summary) {
    return (
      <div className="info-card text-muted">
        {lang === "en" ? "Couldn't load dashboard stats." : "Не удалось загрузить статистику."}
      </div>
    );
  }

  const cards = [
    { label: lang === "en" ? "Sales today" : "Продажи сегодня", value: formatPrice(summary.sales_today) },
    { label: lang === "en" ? "Orders today" : "Заказы сегодня", value: summary.orders_today },
    { label: lang === "en" ? "Orders total" : "Заказы всего", value: summary.orders_total },
    { label: lang === "en" ? "Available balance" : "Доступно к выплате", value: formatPrice(summary.available_balance) },
    { label: lang === "en" ? "Pending balance" : "В обработке", value: formatPrice(summary.pending_balance) },
    { label: lang === "en" ? "Active offers" : "Активные предложения", value: summary.active_offers },
    { label: lang === "en" ? "Low stock" : "Заканчивается", value: summary.low_stock_offers },
    { label: lang === "en" ? "Rating" : "Рейтинг", value: `★ ${summary.rating.toFixed(1)} (${summary.review_count})` },
  ];

  return (
    <div className="stat-grid">
      {cards.map((c) => (
        <div className="stat-card" key={c.label}>
          <span className="stat-label">{c.label}</span>
          <span className="stat-value">{c.value}</span>
        </div>
      ))}
    </div>
  );
}

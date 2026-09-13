"use client";

import { useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { getAdminOverview } from "@/lib/api/adminOverview";
import { formatPrice } from "@/lib/currency";

/** Stage 8: every card maps 1:1 to a real field from GET /admin/overview —
 * no fabricated conversion rate/return rate/monthly chart (the backend
 * doesn't compute either), unlike the Stage 4 mock this replaces. */
export default function AdminOverview() {
  const { lang } = useLanguage();
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getAdminOverview()
      .then(setSummary)
      .catch(() => setSummary(null))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return null;

  if (!summary) {
    return (
      <div className="info-card text-muted">
        {lang === "en" ? "Couldn't load overview stats." : "Не удалось загрузить статистику."}
      </div>
    );
  }

  const cards = [
    { label: "GMV", value: formatPrice(summary.gmv) },
    { label: lang === "en" ? "Orders" : "Заказы", value: summary.orders_total },
    { label: lang === "en" ? "Orders today" : "Заказы сегодня", value: summary.orders_today },
    { label: lang === "en" ? "Customers" : "Покупатели", value: summary.customers_total },
    { label: lang === "en" ? "Sellers" : "Продавцы", value: `${summary.active_sellers} / ${summary.sellers_total}` },
    { label: lang === "en" ? "Marketplace Revenue" : "Доход маркетплейса", value: formatPrice(summary.marketplace_revenue) },
    { label: lang === "en" ? "Average Order Value" : "Средний чек", value: formatPrice(summary.average_order_value) },
    { label: lang === "en" ? "Products" : "Товары", value: `${summary.active_products} / ${summary.products_total}` },
    { label: lang === "en" ? "Active offers" : "Активные предложения", value: summary.active_offers },
    { label: lang === "en" ? "Pending payouts" : "Выплаты в ожидании", value: `${summary.pending_payouts} (${formatPrice(summary.pending_payout_amount)})` },
    { label: lang === "en" ? "Reviews" : "Отзывы", value: summary.reviews_total },
    { label: lang === "en" ? "Hidden reviews" : "Скрытые отзывы", value: summary.hidden_reviews },
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

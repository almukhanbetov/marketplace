"use client";

import { useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { getAdminPayments } from "@/lib/api/adminPayments";
import { formatPrice } from "@/lib/currency";

const STATUS_CLASS = { pending: "status-pill--new", paid: "status-pill--done", failed: "status-pill--cancel", cancelled: "status-pill--cancel", refunded: "status-pill--progress" };

/** Stage 8 §23/§57: read-only, no real gateway actions — mock providers
 * are labeled by their own provider value (kaspi_mock, apple_pay_mock...). */
export default function AdminPayments() {
  const { lang } = useLanguage();
  const [payments, setPayments] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getAdminPayments({ limit: 100 })
      .then(({ items }) => setPayments(items))
      .catch(() => setPayments([]))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="data-table-wrap">
      <table className="data-table">
        <thead>
          <tr>
            <th>{lang === "en" ? "Order" : "Заказ"}</th>
            <th>{lang === "en" ? "Provider" : "Провайдер"}</th>
            <th>{lang === "en" ? "Amount" : "Сумма"}</th>
            <th>{lang === "en" ? "Status" : "Статус"}</th>
            <th>{lang === "en" ? "Date" : "Дата"}</th>
          </tr>
        </thead>
        <tbody>
          {loading ? null : !payments.length ? (
            <tr>
              <td colSpan={5}>
                <div className="empty-state">
                  <div className="empty-state__icon">💳</div>
                  <h3>{lang === "en" ? "No payments yet" : "Пока нет платежей"}</h3>
                </div>
              </td>
            </tr>
          ) : (
            payments.map((p) => (
              <tr key={p.id}>
                <td>#{p.order_id}</td>
                <td>{p.provider}</td>
                <td>{formatPrice(p.amount)}</td>
                <td>
                  <span className={`status-pill ${STATUS_CLASS[p.status] || ""}`}>{p.status}</span>
                </td>
                <td>{new Date(p.created_at).toLocaleDateString(lang === "en" ? "en-US" : "ru-RU")}</td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );
}

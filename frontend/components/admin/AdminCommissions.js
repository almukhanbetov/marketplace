"use client";

import { useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { getAdminCommissions } from "@/lib/api/adminCommissions";
import { getAdminOverview } from "@/lib/api/adminOverview";
import { formatPrice } from "@/lib/currency";

/** Stage 8 §24/§58: real commission rows; the summary total is the
 * authoritative marketplace_revenue figure from GET /admin/overview
 * (Stage 8 §5), never a sum of just the currently-displayed page. */
export default function AdminCommissions() {
  const { lang } = useLanguage();
  const [commissions, setCommissions] = useState([]);
  const [total, setTotal] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      getAdminCommissions({ limit: 100 }).then(({ items }) => setCommissions(items)).catch(() => setCommissions([])),
      getAdminOverview().then((s) => setTotal(s.marketplace_revenue)).catch(() => setTotal(null)),
    ]).finally(() => setLoading(false));
  }, []);

  return (
    <div>
      {total !== null && (
        <div className="commission-widget" style={{ maxWidth: 360, marginBottom: 18 }}>
          <div className="commission-row"><span>{lang === "en" ? "Marketplace commission total" : "Всего комиссии маркетплейса"}</span><span>{formatPrice(total)}</span></div>
        </div>
      )}
      <div className="data-table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>{lang === "en" ? "Order" : "Заказ"}</th>
              <th>{lang === "en" ? "Seller" : "Продавец"}</th>
              <th>{lang === "en" ? "Rate" : "Ставка"}</th>
              <th>{lang === "en" ? "Amount" : "Сумма"}</th>
              <th>{lang === "en" ? "Date" : "Дата"}</th>
            </tr>
          </thead>
          <tbody>
            {loading ? null : !commissions.length ? (
              <tr>
                <td colSpan={5}>
                  <div className="empty-state">
                    <div className="empty-state__icon">💠</div>
                    <h3>{lang === "en" ? "No commissions yet" : "Пока нет комиссий"}</h3>
                  </div>
                </td>
              </tr>
            ) : (
              commissions.map((c) => (
                <tr key={c.id}>
                  <td>#{c.order_id}</td>
                  <td>{c.seller_name}</td>
                  <td>{Math.round(Number(c.rate) * 100)}%</td>
                  <td>{formatPrice(c.amount)}</td>
                  <td>{new Date(c.created_at).toLocaleDateString(lang === "en" ? "en-US" : "ru-RU")}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

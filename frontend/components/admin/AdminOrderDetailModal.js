"use client";

import { useEffect, useState } from "react";
import Modal from "@/components/ui/Modal";
import { useLanguage } from "@/context/LanguageContext";
import { getAdminOrder } from "@/lib/api/adminOrders";
import { formatPrice } from "@/lib/currency";

/** Stage 8 §21/§56: admin sees every seller's lines on a multi-seller
 * order, grouped by seller, with commission/net breakdown — financial
 * visibility no other role gets. */
export default function AdminOrderDetailModal({ orderId, onClose }) {
  const { lang } = useLanguage();
  const [detail, setDetail] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!orderId) return;
    let cancelled = false;
    setLoading(true);
    getAdminOrder(orderId)
      .then((d) => {
        if (!cancelled) setDetail(d);
      })
      .catch(() => {
        if (!cancelled) setDetail(null);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [orderId]);

  const grouped = {};
  if (detail) {
    for (const item of detail.items) {
      (grouped[item.seller_name] ||= []).push(item);
    }
  }

  return (
    <Modal open={!!orderId} onClose={onClose} title={detail?.order_number || (lang === "en" ? "Order" : "Заказ")} labelledBy="admin-order-detail-title" size="lg">
      {loading ? (
        <div className="text-muted">{lang === "en" ? "Loading..." : "Загрузка..."}</div>
      ) : !detail ? (
        <div className="text-muted">{lang === "en" ? "Couldn't load order." : "Не удалось загрузить заказ."}</div>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
          <div className="info-card">
            <b>{detail.user.full_name}</b>
            <div className="text-muted" style={{ fontSize: "var(--fs-xs)", marginTop: 4 }}>
              {detail.user.email} &middot; {detail.user.phone}
            </div>
            <div className="text-muted" style={{ fontSize: "var(--fs-xs)", marginTop: 4 }}>
              {detail.delivery.city}, {detail.delivery.street} {detail.delivery.house}
              {detail.delivery.apartment ? `, ${lang === "en" ? "apt." : "кв."} ${detail.delivery.apartment}` : ""}
            </div>
          </div>

          {Object.entries(grouped).map(([sellerName, items]) => (
            <div key={sellerName} className="info-card">
              <b>{sellerName}</b>
              <div className="data-table-wrap" style={{ marginTop: 8 }}>
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>SKU</th>
                      <th>{lang === "en" ? "Product" : "Товар"}</th>
                      <th>{lang === "en" ? "Qty" : "Кол-во"}</th>
                      <th>{lang === "en" ? "Total" : "Сумма"}</th>
                      <th>{lang === "en" ? "Commission" : "Комиссия"}</th>
                      <th>{lang === "en" ? "Seller net" : "Продавцу"}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {items.map((it, i) => (
                      <tr key={i}>
                        <td>{it.sku}</td>
                        <td>{it.product_name}</td>
                        <td>{it.quantity}</td>
                        <td>{formatPrice(it.total_price)}</td>
                        <td>{formatPrice(it.commission_amount)}</td>
                        <td>{formatPrice(it.seller_amount)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          ))}

          <div className="commission-widget">
            <div className="commission-row"><span>{lang === "en" ? "Subtotal" : "Товары"}</span><span>{formatPrice(detail.subtotal)}</span></div>
            <div className="commission-row"><span>{lang === "en" ? "Delivery" : "Доставка"}</span><span>{formatPrice(detail.delivery_total)}</span></div>
            <div className="commission-row"><span>{lang === "en" ? "Commission" : "Комиссия"}</span><span>{formatPrice(detail.commission_total)}</span></div>
            <div className="commission-row"><span>{lang === "en" ? "Total" : "Итого"}</span><span>{formatPrice(detail.total)}</span></div>
            {detail.payment && (
              <div className="commission-row">
                <span>{lang === "en" ? "Payment" : "Оплата"}</span>
                <span>{detail.payment.provider} &middot; {detail.payment.status}</span>
              </div>
            )}
          </div>
        </div>
      )}
    </Modal>
  );
}

"use client";

import { useEffect, useState } from "react";
import Modal from "@/components/ui/Modal";
import { useLanguage } from "@/context/LanguageContext";
import { getSellerOrder } from "@/lib/api/sellerOrders";
import { formatPrice } from "@/lib/currency";

export default function SellerOrderDetailModal({ orderId, onClose }) {
  const { lang } = useLanguage();
  const [detail, setDetail] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!orderId) return;
    let cancelled = false;
    setLoading(true);
    getSellerOrder(orderId)
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

  return (
    <Modal open={!!orderId} onClose={onClose} title={detail?.order_number || (lang === "en" ? "Order" : "Заказ")} labelledBy="seller-order-detail-title">
      {loading ? (
        <div className="text-muted">{lang === "en" ? "Loading..." : "Загрузка..."}</div>
      ) : !detail ? (
        <div className="text-muted">{lang === "en" ? "Couldn't load order." : "Не удалось загрузить заказ."}</div>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
          <div className="info-card">
            <b>{lang === "en" ? "Delivery" : "Доставка"}</b>
            <div className="text-muted" style={{ fontSize: "var(--fs-xs)", marginTop: 4 }}>
              {detail.delivery.city}, {detail.delivery.street} {detail.delivery.house}
              {detail.delivery.apartment ? `, ${lang === "en" ? "apt." : "кв."} ${detail.delivery.apartment}` : ""}
            </div>
          </div>

          <div className="data-table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>SKU</th>
                  <th>{lang === "en" ? "Product" : "Товар"}</th>
                  <th>{lang === "en" ? "Qty" : "Кол-во"}</th>
                  <th>{lang === "en" ? "Total" : "Сумма"}</th>
                </tr>
              </thead>
              <tbody>
                {detail.items.map((it, i) => (
                  <tr key={i}>
                    <td>{it.sku}</td>
                    <td>{it.product_name}</td>
                    <td>{it.quantity}</td>
                    <td>{formatPrice(it.total_price)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div style={{ display: "flex", justifyContent: "space-between" }}>
            <span className="text-muted">{lang === "en" ? "Your net amount" : "Ваша сумма к получению"}</span>
            <b>{formatPrice(detail.seller_net_amount)}</b>
          </div>
        </div>
      )}
    </Modal>
  );
}

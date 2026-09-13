"use client";

import { useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { getSellerOrders } from "@/lib/api/sellerOrders";
import { formatPrice } from "@/lib/currency";
import SellerOrderDetailModal from "@/components/seller/SellerOrderDetailModal";

const STATUS_LABELS_RU = {
  new: "Новый", confirmed: "Подтверждён", paid: "Оплачен", processing: "Собирается",
  shipped: "Передан в доставку", delivered: "Доставлен", cancelled: "Отменён", returned: "Возврат",
};
const STATUS_LABELS_EN = {
  new: "New", confirmed: "Confirmed", paid: "Paid", processing: "Processing",
  shipped: "Shipped", delivered: "Delivered", cancelled: "Cancelled", returned: "Returned",
};
const STATUS_CLASS = {
  new: "status-pill--new", confirmed: "status-pill--progress", paid: "status-pill--progress", processing: "status-pill--progress",
  shipped: "status-pill--progress", delivered: "status-pill--done", cancelled: "status-pill--cancel", returned: "status-pill--cancel",
};

/** Stage 7 §16/§17: seller orders are READ-ONLY on purpose. The schema has
 * no per-seller fulfillment/suborder entity (no order_fulfillments/
 * seller_orders table, one row per order_id+seller_id), so a status
 * dropdown here would mutate the single global orders.status — corrupting
 * other sellers'/the customer's view of the same order. The Stage 4 mock
 * this replaces had exactly that unsafe dropdown; it's removed rather than
 * wired to a real endpoint that doesn't exist. */
export default function SellerOrders() {
  const { lang } = useLanguage();
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [openOrderId, setOpenOrderId] = useState(null);
  const statusLabels = lang === "en" ? STATUS_LABELS_EN : STATUS_LABELS_RU;

  useEffect(() => {
    getSellerOrders({ limit: 100 })
      .then(({ items }) => setOrders(items))
      .catch(() => setOrders([]))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div>
      <div className="data-table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>{lang === "en" ? "Order" : "Заказ"}</th>
              <th>{lang === "en" ? "Items" : "Товары"}</th>
              <th>{lang === "en" ? "Your amount" : "Ваша сумма"}</th>
              <th>{lang === "en" ? "Status" : "Статус"}</th>
              <th>{lang === "en" ? "Date" : "Дата"}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {loading ? null : !orders.length ? (
              <tr>
                <td colSpan={6}>
                  <div className="empty-state">
                    <div className="empty-state__icon">🧾</div>
                    <h3>{lang === "en" ? "No orders yet" : "Пока нет заказов"}</h3>
                  </div>
                </td>
              </tr>
            ) : (
              orders.map((o) => (
                <tr key={o.order_id}>
                  <td>{o.order_number}</td>
                  <td>{o.seller_item_count}</td>
                  <td>{formatPrice(o.seller_net_amount)}</td>
                  <td>
                    <span className={`status-pill ${STATUS_CLASS[o.status] || ""}`}>{statusLabels[o.status] || o.status}</span>
                  </td>
                  <td>{new Date(o.created_at).toLocaleDateString(lang === "en" ? "en-US" : "ru-RU")}</td>
                  <td className="row-actions">
                    <button aria-label={lang === "en" ? "Details" : "Подробнее"} onClick={() => setOpenOrderId(o.order_id)}>👁</button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <SellerOrderDetailModal orderId={openOrderId} onClose={() => setOpenOrderId(null)} />
    </div>
  );
}

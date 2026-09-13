"use client";

import { useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { getAdminOrders } from "@/lib/api/adminOrders";
import { formatPrice } from "@/lib/currency";
import AdminOrderDetailModal from "@/components/admin/AdminOrderDetailModal";

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

/** Stage 8 §22/§55: marketplace-wide orders, read-only — no status
 * dropdown (the backend has no order status-mutation route). */
export default function AdminOrders() {
  const { lang } = useLanguage();
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [openOrderId, setOpenOrderId] = useState(null);
  const statusLabels = lang === "en" ? STATUS_LABELS_EN : STATUS_LABELS_RU;

  useEffect(() => {
    getAdminOrders({ limit: 100 })
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
              <th>{lang === "en" ? "Customer" : "Покупатель"}</th>
              <th>{lang === "en" ? "Items" : "Товары"}</th>
              <th>{lang === "en" ? "Sellers" : "Продавцы"}</th>
              <th>{lang === "en" ? "Total" : "Сумма"}</th>
              <th>{lang === "en" ? "Payment" : "Оплата"}</th>
              <th>{lang === "en" ? "Status" : "Статус"}</th>
              <th>{lang === "en" ? "Date" : "Дата"}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {loading ? null : !orders.length ? (
              <tr>
                <td colSpan={9}>
                  <div className="empty-state">
                    <div className="empty-state__icon">🧾</div>
                    <h3>{lang === "en" ? "No orders yet" : "Пока нет заказов"}</h3>
                  </div>
                </td>
              </tr>
            ) : (
              orders.map((o) => (
                <tr key={o.id}>
                  <td>{o.order_number}</td>
                  <td>{o.user.full_name}</td>
                  <td>{o.item_count}</td>
                  <td>{o.seller_count}</td>
                  <td>{formatPrice(o.total)}</td>
                  <td>{o.payment_status}</td>
                  <td>
                    <span className={`status-pill ${STATUS_CLASS[o.status] || ""}`}>{statusLabels[o.status] || o.status}</span>
                  </td>
                  <td>{new Date(o.created_at).toLocaleDateString(lang === "en" ? "en-US" : "ru-RU")}</td>
                  <td className="row-actions">
                    <button aria-label={lang === "en" ? "Details" : "Подробнее"} onClick={() => setOpenOrderId(o.id)}>👁</button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <AdminOrderDetailModal orderId={openOrderId} onClose={() => setOpenOrderId(null)} />
    </div>
  );
}

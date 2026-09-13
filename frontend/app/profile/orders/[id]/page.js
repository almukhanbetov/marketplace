"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { useLanguage } from "@/context/LanguageContext";
import { getOrder } from "@/lib/api/orders";
import { formatPrice } from "@/lib/currency";

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

export default function OrderDetailPage() {
  const { t, lang } = useLanguage();
  const params = useParams();
  const [order, setOrder] = useState(null);
  const [loading, setLoading] = useState(true);
  const [notFound, setNotFound] = useState(false);

  useEffect(() => {
    let cancelled = false;
    getOrder(params.id)
      .then((data) => {
        if (!cancelled) setOrder(data);
      })
      .catch(() => {
        if (!cancelled) setNotFound(true);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [params.id]);

  const statusLabels = lang === "en" ? STATUS_LABELS_EN : STATUS_LABELS_RU;

  function formatAddress(d) {
    if (!d) return "";
    const parts = [d.city, `${d.street} ${d.house}`];
    if (d.apartment) parts.push((lang === "en" ? "apt. " : "кв. ") + d.apartment);
    return parts.join(", ");
  }

  return (
    <div className="container page-section--tight">
      <nav className="breadcrumbs" aria-label="Breadcrumb">
        <Link href="/">{t("home")}</Link>
        <span aria-hidden="true">/</span>
        <Link href="/profile">{t("profile")}</Link>
        <span aria-hidden="true">/</span>
        <span>{t("orders")}</span>
      </nav>

      {loading && <p className="text-muted">{lang === "en" ? "Loading…" : "Загрузка…"}</p>}

      {!loading && (notFound || !order) && (
        <div className="empty-state">
          <div className="empty-state__icon">📦</div>
          <h3>{lang === "en" ? "Order not found" : "Заказ не найден"}</h3>
          <Link href="/profile" className="btn btn--primary btn--lg" style={{ marginTop: 10 }}>
            {t("profile")}
          </Link>
        </div>
      )}

      {!loading && order && (
        <>
          <div className="order-card-head" style={{ marginBottom: 20 }}>
            <div>
              <h1 style={{ fontSize: "var(--fs-xl)", fontWeight: 800 }}>№ {order.order_number}</h1>
              <div className="text-muted" style={{ fontSize: "var(--fs-sm)" }}>
                {new Date(order.created_at).toLocaleString(lang === "en" ? "en-US" : "ru-RU")}
              </div>
            </div>
            <span className={`status-pill ${STATUS_CLASS[order.status] || ""}`}>
              {statusLabels[order.status] || order.status}
            </span>
          </div>

          <div className="layout-with-sidebar">
            <div>
              <div className="info-card" style={{ marginBottom: 14 }}>
                <h3 style={{ fontSize: "var(--fs-md)", fontWeight: 800, marginBottom: 14 }}>
                  {lang === "en" ? "Items" : "Товары"}
                </h3>
                {order.items.map((item, i) => (
                  <div className="cart-line" key={i}>
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={item.primary_image} alt="" />
                    <div>
                      <div className="cart-line-title">{item.product_name}</div>
                      <div className="cart-line-seller">
                        {t("sellerLabel")}: {item.seller_name}
                      </div>
                      <div className="text-muted" style={{ fontSize: "var(--fs-xs)" }}>
                        {formatPrice(item.unit_price)} × {item.quantity}
                      </div>
                    </div>
                    <div className="cart-line-price">{formatPrice(item.total_price)}</div>
                  </div>
                ))}
              </div>

              <div className="info-card">
                <h3 style={{ fontSize: "var(--fs-md)", fontWeight: 800, marginBottom: 10 }}>
                  {lang === "en" ? "Delivery address" : "Адрес доставки"}
                </h3>
                {order.delivery?.title && <div><b>{order.delivery.title}</b></div>}
                <div className="text-muted">{formatAddress(order.delivery)}</div>
              </div>
            </div>

            <aside className="sidebar-card">
              <h3 style={{ fontSize: "var(--fs-md)", fontWeight: 800, marginBottom: 14 }}>{t("total")}</h3>
              <div className="summary-row">
                <span>{lang === "en" ? "Subtotal" : "Товары"}</span>
                <span>{formatPrice(order.subtotal)}</span>
              </div>
              <div className="summary-row">
                <span>{t("discount")}</span>
                <span>{Number(order.discount_total) > 0 ? `−${formatPrice(order.discount_total)}` : formatPrice(0)}</span>
              </div>
              <div className="summary-row">
                <span>{t("shipping")}</span>
                <span>{Number(order.delivery_total) > 0 ? formatPrice(order.delivery_total) : t("free")}</span>
              </div>
              <div className="summary-row total">
                <span>{t("total")}</span>
                <span>{formatPrice(order.total)}</span>
              </div>
              {order.payment && (
                <div className="summary-row" style={{ marginTop: 10 }}>
                  <span>{t("payment")}</span>
                  <span>{order.payment.provider} · {order.payment.status}</span>
                </div>
              )}
            </aside>
          </div>
        </>
      )}
    </div>
  );
}

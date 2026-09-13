"use client";

import { useEffect, useState } from "react";
import Modal from "@/components/ui/Modal";
import { useLanguage } from "@/context/LanguageContext";
import { getAdminSeller } from "@/lib/api/adminSellers";
import { formatPrice } from "@/lib/currency";

export default function AdminSellerDetailModal({ sellerId, onClose }) {
  const { lang } = useLanguage();
  const [detail, setDetail] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!sellerId) return;
    let cancelled = false;
    setLoading(true);
    getAdminSeller(sellerId)
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
  }, [sellerId]);

  return (
    <Modal open={!!sellerId} onClose={onClose} title={detail?.name || (lang === "en" ? "Seller" : "Продавец")} labelledBy="admin-seller-detail-title">
      {loading ? (
        <div className="text-muted">{lang === "en" ? "Loading..." : "Загрузка..."}</div>
      ) : !detail ? (
        <div className="text-muted">{lang === "en" ? "Couldn't load seller." : "Не удалось загрузить продавца."}</div>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
          <div className="info-card">
            <div className="text-muted" style={{ fontSize: "var(--fs-xs)" }}>{detail.account_email} &middot; {detail.account_phone}</div>
            <div style={{ marginTop: 6 }}>
              <span className={`status-pill ${detail.is_active ? "status-pill--done" : "status-pill--cancel"}`}>
                {detail.is_active ? (lang === "en" ? "Active" : "Активен") : (lang === "en" ? "Inactive" : "Неактивен")}
              </span>{" "}
              {detail.is_verified && <span className="status-pill status-pill--progress">{lang === "en" ? "Verified" : "Верифицирован"}</span>}
            </div>
          </div>

          <div className="commission-widget">
            <div className="commission-row"><span>{lang === "en" ? "Offers (active / total)" : "Предложения (активные / всего)"}</span><span>{detail.active_offer_count} / {detail.total_offer_count}</span></div>
            <div className="commission-row"><span>{lang === "en" ? "Low stock" : "Мало на складе"}</span><span>{detail.low_stock_offers}</span></div>
            <div className="commission-row"><span>{lang === "en" ? "Orders" : "Заказы"}</span><span>{detail.order_count}</span></div>
            <div className="commission-row"><span>{lang === "en" ? "Gross sales" : "Выручка"}</span><span>{formatPrice(detail.gross_sales)}</span></div>
            <div className="commission-row"><span>{lang === "en" ? "Commission generated" : "Начислено комиссии"}</span><span>{formatPrice(detail.commission_generated)}</span></div>
            <div className="commission-row"><span>{lang === "en" ? "Pending balance" : "В обработке"}</span><span>{formatPrice(detail.pending_balance)}</span></div>
            <div className="commission-row"><span>{lang === "en" ? "Available balance" : "Доступно"}</span><span>{formatPrice(detail.available_balance)}</span></div>
            <div className="commission-row"><span>{lang === "en" ? "Payouts" : "Выплаты"}</span><span>{detail.payout_count}</span></div>
          </div>
        </div>
      )}
    </Modal>
  );
}

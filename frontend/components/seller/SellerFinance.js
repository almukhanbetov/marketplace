"use client";

import { useCallback, useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";
import { getSellerFinance } from "@/lib/api/sellerFinance";
import { getSellerPayouts, createSellerPayout } from "@/lib/api/sellerPayouts";
import { formatPrice } from "@/lib/currency";

function newIdempotencyKey() {
  if (typeof crypto !== "undefined" && crypto.randomUUID) return crypto.randomUUID();
  return "idem-" + Date.now() + "-" + Math.random().toString(16).slice(2);
}

const PAYOUT_STATUS_RU = { pending: "В обработке", processing: "Обрабатывается", paid: "Выплачено", rejected: "Отклонено" };
const PAYOUT_STATUS_EN = { pending: "Pending", processing: "Processing", paid: "Paid", rejected: "Rejected" };
const PAYOUT_STATUS_CLASS = { pending: "status-pill--new", processing: "status-pill--progress", paid: "status-pill--done", rejected: "status-pill--cancel" };

/** Stage 7 §18/§19/§20-26: real gross/commission/net/pending/available
 * from GET /sellers/:id/finance, and a real payout request against
 * GET/POST /sellers/:id/payouts — no fabricated "logistics"/"returns" line
 * items (the Stage 4 mock this replaces invented both; the backend has
 * neither concept in Stage 7). */
export default function SellerFinance() {
  const { lang } = useLanguage();
  const { showToast } = useToast();
  const [finance, setFinance] = useState(null);
  const [payouts, setPayouts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [amount, setAmount] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const refresh = useCallback(() => {
    return Promise.all([
      getSellerFinance().then(setFinance).catch(() => setFinance(null)),
      getSellerPayouts().then(setPayouts).catch(() => setPayouts([])),
    ]);
  }, []);

  useEffect(() => {
    refresh().finally(() => setLoading(false));
  }, [refresh]);

  async function requestPayout(e) {
    e.preventDefault();
    const value = Number(amount);
    if (!Number.isFinite(value) || value <= 0) {
      showToast(lang === "en" ? "Enter a valid amount." : "Введите корректную сумму.", "warn", "⚠");
      return;
    }
    const available = Number(finance?.available_balance || 0);
    if (value > available) {
      showToast(lang === "en" ? "Amount exceeds your available balance." : "Сумма превышает доступный баланс.", "warn", "⚠");
      return;
    }
    setSubmitting(true);
    try {
      await createSellerPayout(value.toFixed(2), newIdempotencyKey());
      showToast(lang === "en" ? "Payout requested" : "Запрос на выплату отправлен", "success", "✓");
      setAmount("");
      await refresh();
    } catch (err) {
      const message =
        err?.code === "INSUFFICIENT_AVAILABLE_BALANCE"
          ? (lang === "en" ? "Amount exceeds your available balance." : "Сумма превышает доступный баланс.")
          : err?.message || (lang === "en" ? "Couldn't request payout." : "Не удалось создать запрос на выплату.");
      showToast(message, "warn", "⚠");
    } finally {
      setSubmitting(false);
    }
  }

  if (loading) return null;
  const payoutStatusLabels = lang === "en" ? PAYOUT_STATUS_EN : PAYOUT_STATUS_RU;

  return (
    <div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 18 }}>
        <div className="commission-widget">
          <h4 style={{ fontSize: "var(--fs-sm)", fontWeight: 700, marginBottom: 8 }}>
            {lang === "en" ? "Finance" : "Финансы"}
          </h4>
          {!finance ? (
            <div className="text-muted">{lang === "en" ? "Couldn't load finance data." : "Не удалось загрузить финансы."}</div>
          ) : (
            <>
              <div className="commission-row"><span>{lang === "en" ? "Gross sales" : "Выручка"}</span><span>{formatPrice(finance.gross_sales)}</span></div>
              <div className="commission-row"><span>{lang === "en" ? "Commission" : "Комиссия Marketplace"}</span><span className="neg">−{formatPrice(finance.commission_total)}</span></div>
              <div className="commission-row"><span>{lang === "en" ? "Net" : "Чистыми"}</span><span className="pos">{formatPrice(finance.seller_net_total)}</span></div>
              <div className="commission-row"><span>{lang === "en" ? "Pending" : "В обработке"}</span><span>{formatPrice(finance.pending_balance)}</span></div>
              <div className="commission-row"><span>{lang === "en" ? "Available" : "Доступно к выплате"}</span><span className="pos">{formatPrice(finance.available_balance)}</span></div>
              <div className="commission-row"><span>{lang === "en" ? "Already paid out" : "Уже выплачено"}</span><span>{formatPrice(finance.paid_out_total)}</span></div>
            </>
          )}
        </div>

        <div className="commission-widget">
          <h4 style={{ fontSize: "var(--fs-sm)", fontWeight: 700, marginBottom: 8 }}>
            {lang === "en" ? "Request a payout" : "Запросить выплату"}
          </h4>
          <p className="text-muted" style={{ fontSize: "var(--fs-xs)", marginBottom: 12 }}>
            {lang === "en"
              ? "Payouts can only be drawn from your available balance — funds still pending cannot be withdrawn yet."
              : "Выплата производится только с доступного баланса — средства в обработке пока недоступны."}
          </p>
          <form onSubmit={requestPayout} style={{ display: "flex", gap: 10 }}>
            <input
              type="number"
              min="0"
              step="0.01"
              placeholder={lang === "en" ? "Amount" : "Сумма"}
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              style={{ flex: 1 }}
            />
            <button type="submit" className="btn btn--primary" disabled={submitting}>
              {lang === "en" ? "Request" : "Запросить"}
            </button>
          </form>
        </div>
      </div>

      <div className="info-card" style={{ marginTop: 18 }}>
        <h4 style={{ fontSize: "var(--fs-sm)", fontWeight: 700, marginBottom: 12 }}>
          {lang === "en" ? "Payout history" : "История выплат"}
        </h4>
        <div className="data-table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>{lang === "en" ? "Requested" : "Дата запроса"}</th>
                <th>{lang === "en" ? "Amount" : "Сумма"}</th>
                <th>{lang === "en" ? "Status" : "Статус"}</th>
              </tr>
            </thead>
            <tbody>
              {!payouts.length ? (
                <tr>
                  <td colSpan={3}>
                    <div className="empty-state">
                      <div className="empty-state__icon">💸</div>
                      <h3>{lang === "en" ? "No payouts yet" : "Пока нет выплат"}</h3>
                    </div>
                  </td>
                </tr>
              ) : (
                payouts.map((p) => (
                  <tr key={p.id}>
                    <td>{new Date(p.requested_at).toLocaleDateString(lang === "en" ? "en-US" : "ru-RU")}</td>
                    <td>{formatPrice(p.amount)}</td>
                    <td>
                      <span className={`status-pill ${PAYOUT_STATUS_CLASS[p.status] || ""}`}>{payoutStatusLabels[p.status] || p.status}</span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

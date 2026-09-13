"use client";

import { useCallback, useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { getAdminPayouts } from "@/lib/api/adminPayouts";
import { formatPrice } from "@/lib/currency";
import AdminPayoutConfirmModal from "@/components/admin/AdminPayoutConfirmModal";

const STATUS_LABELS_RU = { pending: "В обработке", processing: "Обрабатывается", paid: "Выплачено", rejected: "Отклонено" };
const STATUS_LABELS_EN = { pending: "Pending", processing: "Processing", paid: "Paid", rejected: "Rejected" };
const STATUS_CLASS = { pending: "status-pill--new", processing: "status-pill--progress", paid: "status-pill--done", rejected: "status-pill--cancel" };

/** Stage 8 §25/§26/§59: allowed transitions depend on current status —
 * pending: Process/Reject; processing: Mark Paid/Reject; paid/rejected:
 * no transition actions (terminal). */
export default function AdminPayouts() {
  const { lang } = useLanguage();
  const [payouts, setPayouts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [pending, setPending] = useState(null); // { payout, targetStatus }
  const statusLabels = lang === "en" ? STATUS_LABELS_EN : STATUS_LABELS_RU;

  const refresh = useCallback(() => {
    return getAdminPayouts({ limit: 100 })
      .then(({ items }) => setPayouts(items))
      .catch(() => setPayouts([]));
  }, []);

  useEffect(() => {
    setLoading(true);
    refresh().finally(() => setLoading(false));
  }, [refresh]);

  return (
    <div>
      <div className="data-table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>{lang === "en" ? "Seller" : "Продавец"}</th>
              <th>{lang === "en" ? "Amount" : "Сумма"}</th>
              <th>{lang === "en" ? "Status" : "Статус"}</th>
              <th>{lang === "en" ? "Requested" : "Запрошена"}</th>
              <th>{lang === "en" ? "Processed" : "Обработана"}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {loading ? null : !payouts.length ? (
              <tr>
                <td colSpan={6}>
                  <div className="empty-state">
                    <div className="empty-state__icon">💸</div>
                    <h3>{lang === "en" ? "No payouts yet" : "Пока нет выплат"}</h3>
                  </div>
                </td>
              </tr>
            ) : (
              payouts.map((p) => (
                <tr key={p.id}>
                  <td>{p.seller_name}</td>
                  <td>{formatPrice(p.amount)}</td>
                  <td>
                    <span className={`status-pill ${STATUS_CLASS[p.status] || ""}`}>{statusLabels[p.status] || p.status}</span>
                  </td>
                  <td>{new Date(p.requested_at).toLocaleDateString(lang === "en" ? "en-US" : "ru-RU")}</td>
                  <td>{p.processed_at ? new Date(p.processed_at).toLocaleDateString(lang === "en" ? "en-US" : "ru-RU") : "—"}</td>
                  <td className="row-actions">
                    {p.status === "pending" && (
                      <>
                        <button aria-label={lang === "en" ? "Start processing" : "В обработку"} onClick={() => setPending({ payout: p, targetStatus: "processing" })}>▶</button>
                        <button aria-label={lang === "en" ? "Reject" : "Отклонить"} onClick={() => setPending({ payout: p, targetStatus: "rejected" })}>✕</button>
                      </>
                    )}
                    {p.status === "processing" && (
                      <>
                        <button aria-label={lang === "en" ? "Mark as paid" : "Отметить выплаченной"} onClick={() => setPending({ payout: p, targetStatus: "paid" })}>✓</button>
                        <button aria-label={lang === "en" ? "Reject" : "Отклонить"} onClick={() => setPending({ payout: p, targetStatus: "rejected" })}>✕</button>
                      </>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <AdminPayoutConfirmModal
        payout={pending?.payout}
        targetStatus={pending?.targetStatus}
        onClose={() => setPending(null)}
        onConfirmed={refresh}
      />
    </div>
  );
}

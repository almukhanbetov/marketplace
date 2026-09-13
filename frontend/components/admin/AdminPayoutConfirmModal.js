"use client";

import { useState } from "react";
import Modal from "@/components/ui/Modal";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";
import { setAdminPayoutStatus } from "@/lib/api/adminPayouts";
import { formatPrice } from "@/lib/currency";

const ACTION_COPY = {
  processing: { ru: "Взять в обработку", en: "Start processing" },
  paid: { ru: "Отметить как выплачено", en: "Mark as paid" },
  rejected: { ru: "Отклонить", en: "Reject" },
};

/** Stage 8 §60: confirmation before every payout transition — rejection
 * especially, since it refunds the seller's available balance. */
export default function AdminPayoutConfirmModal({ payout, targetStatus, onClose, onConfirmed }) {
  const { lang } = useLanguage();
  const { showToast } = useToast();
  const [submitting, setSubmitting] = useState(false);

  if (!payout || !targetStatus) return null;
  const copy = ACTION_COPY[targetStatus];

  async function confirm() {
    setSubmitting(true);
    try {
      await setAdminPayoutStatus(payout.id, targetStatus);
      showToast(lang === "en" ? "Payout updated" : "Выплата обновлена", "success", "✓");
      onConfirmed?.();
      onClose();
    } catch (err) {
      const message =
        err?.code === "INVALID_PAYOUT_STATUS_TRANSITION"
          ? (lang === "en" ? "This payout can no longer make that transition." : "Эта выплата больше не может перейти в этот статус.")
          : err?.message || (lang === "en" ? "Couldn't update payout." : "Не удалось обновить выплату.");
      showToast(message, "warn", "⚠");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal open={!!payout} onClose={onClose} title={copy ? (lang === "en" ? copy.en : copy.ru) : ""} labelledBy="admin-payout-confirm-title">
      <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
        <div className="info-card">
          <b>{payout.seller_name}</b>
          <div className="text-muted" style={{ fontSize: "var(--fs-xs)", marginTop: 4 }}>{formatPrice(payout.amount)}</div>
        </div>
        {targetStatus === "rejected" && (
          <p className="text-muted" style={{ fontSize: "var(--fs-sm)" }}>
            {lang === "en"
              ? "Rejecting this payout will refund its amount back to the seller's available balance."
              : "Отклонение выплаты вернёт её сумму на доступный баланс продавца."}
          </p>
        )}
        <div style={{ display: "flex", gap: 10 }}>
          <button className="btn btn--primary" disabled={submitting} onClick={confirm}>
            {copy ? (lang === "en" ? copy.en : copy.ru) : (lang === "en" ? "Confirm" : "Подтвердить")}
          </button>
          <button className="btn btn--outline" onClick={onClose} disabled={submitting}>
            {lang === "en" ? "Cancel" : "Отмена"}
          </button>
        </div>
      </div>
    </Modal>
  );
}

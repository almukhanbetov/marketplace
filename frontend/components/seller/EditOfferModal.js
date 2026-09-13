"use client";

import { useEffect, useState } from "react";
import Modal from "@/components/ui/Modal";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";
import { updateSellerOffer } from "@/lib/api/sellerOffers";
import { getLocalizedValue } from "@/lib/api/adapters";

/** Stage 7 §8: only sku/price/old_price/delivery_days are editable here —
 * seller_id/product_id can never be reassigned through this form. */
export default function EditOfferModal({ open, offer, onClose, onUpdated }) {
  const { lang } = useLanguage();
  const { showToast } = useToast();
  const [form, setForm] = useState({ sku: "", price: "", oldPrice: "", deliveryDays: "0" });
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (offer) {
      setForm({
        sku: offer.sku,
        price: offer.price,
        oldPrice: offer.old_price || "",
        deliveryDays: String(offer.delivery_days ?? 0),
      });
    }
  }, [offer]);

  function set(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
  }

  async function submit(e) {
    e.preventDefault();
    if (!offer) return;
    setSaving(true);
    try {
      await updateSellerOffer(offer.id, {
        sku: form.sku.trim(),
        price: form.price,
        oldPrice: form.oldPrice || "",
        deliveryDays: Number(form.deliveryDays) || 0,
      });
      showToast(lang === "en" ? "Offer updated" : "Предложение обновлено", "success", "✓");
      onUpdated?.();
      onClose();
    } catch (err) {
      showToast(err?.message || (lang === "en" ? "Couldn't update the offer." : "Не удалось обновить предложение."), "warn", "⚠");
    } finally {
      setSaving(false);
    }
  }

  if (!offer) return null;

  return (
    <Modal open={open} onClose={onClose} title={lang === "en" ? "Edit offer" : "Изменить предложение"} labelledBy="edit-offer-title">
      <form style={{ display: "flex", flexDirection: "column", gap: 14 }} onSubmit={submit}>
        <div className="text-muted" style={{ fontSize: "var(--fs-sm)" }}>{getLocalizedValue(offer.product_name, lang)}</div>
        <div className="field">
          <label>SKU</label>
          <input required value={form.sku} onChange={(e) => set("sku", e.target.value)} />
        </div>
        <div style={{ display: "flex", gap: 12 }}>
          <div className="field" style={{ flex: 1 }}>
            <label>{lang === "en" ? "Price" : "Цена"}</label>
            <input type="number" min="0" step="0.01" required value={form.price} onChange={(e) => set("price", e.target.value)} />
          </div>
          <div className="field" style={{ flex: 1 }}>
            <label>{lang === "en" ? "Old price" : "Старая цена"}</label>
            <input type="number" min="0" step="0.01" value={form.oldPrice} onChange={(e) => set("oldPrice", e.target.value)} />
          </div>
        </div>
        <div className="field">
          <label>{lang === "en" ? "Delivery, days" : "Доставка, дней"}</label>
          <input type="number" min="0" required value={form.deliveryDays} onChange={(e) => set("deliveryDays", e.target.value)} />
        </div>
        <button type="submit" className="btn btn--primary btn--block btn--lg" disabled={saving}>
          {lang === "en" ? "Save" : "Сохранить"}
        </button>
      </form>
    </Modal>
  );
}

"use client";

import { useEffect, useState } from "react";
import Modal from "@/components/ui/Modal";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";
import { getProducts } from "@/lib/api/products";
import { createSellerOffer } from "@/lib/api/sellerOffers";
import { getLocalizedValue } from "@/lib/api/adapters";
import { formatPrice } from "@/lib/currency";

const EMPTY_OFFER_FORM = { sku: "", price: "", oldPrice: "", deliveryDays: "1", stock: "" };

/** Stage 7 §35: sellers pick an EXISTING catalog product — this never
 * creates a new global product record. Step 1 searches the public product
 * catalog; step 2 sets only the seller-specific fields (sku/price/old
 * price/delivery days/stock). */
export default function AddOfferModal({ open, onClose, onCreated }) {
  const { lang } = useLanguage();
  const { showToast } = useToast();
  const [search, setSearch] = useState("");
  const [results, setResults] = useState([]);
  const [searching, setSearching] = useState(false);
  const [selected, setSelected] = useState(null);
  const [form, setForm] = useState(EMPTY_OFFER_FORM);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!open) {
      setSearch("");
      setResults([]);
      setSelected(null);
      setForm(EMPTY_OFFER_FORM);
    }
  }, [open]);

  useEffect(() => {
    if (!open || selected) return;
    const term = search.trim();
    let cancelled = false;
    setSearching(true);
    const timer = setTimeout(() => {
      getProducts({ search: term, limit: 8 })
        .then(({ items }) => {
          if (!cancelled) setResults(items);
        })
        .catch(() => {
          if (!cancelled) setResults([]);
        })
        .finally(() => {
          if (!cancelled) setSearching(false);
        });
    }, 250);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [search, open, selected]);

  function set(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
  }

  async function submit(e) {
    e.preventDefault();
    if (!selected) return;
    if (!form.sku.trim() || !form.price || !form.stock) {
      showToast(lang === "en" ? "SKU, price and stock are required." : "SKU, цена и остаток обязательны.", "warn", "⚠");
      return;
    }
    setSaving(true);
    try {
      await createSellerOffer({
        productId: selected.id,
        sku: form.sku.trim(),
        price: form.price,
        oldPrice: form.oldPrice || "",
        deliveryDays: Number(form.deliveryDays) || 0,
        stock: Number(form.stock),
      });
      showToast(lang === "en" ? "Offer added" : "Предложение добавлено", "success", "✓");
      onCreated?.();
      onClose();
    } catch (err) {
      showToast(err?.message || (lang === "en" ? "Couldn't create the offer." : "Не удалось создать предложение."), "warn", "⚠");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal open={open} onClose={onClose} title={lang === "en" ? "Add offer" : "Добавить предложение"} labelledBy="add-offer-title">
      {!selected ? (
        <div>
          <div className="field">
            <label>{lang === "en" ? "Find a catalog product" : "Найдите товар в каталоге"}</label>
            <input
              autoFocus
              placeholder={lang === "en" ? "Search by name..." : "Поиск по названию..."}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 8, marginTop: 12, maxHeight: 320, overflowY: "auto" }}>
            {searching && <div className="text-muted">{lang === "en" ? "Searching..." : "Поиск..."}</div>}
            {!searching && search.trim() && results.length === 0 && (
              <div className="text-muted">{lang === "en" ? "No products found." : "Товары не найдены."}</div>
            )}
            {results.map((p) => (
              <button
                key={p.id}
                type="button"
                className="info-card"
                style={{ display: "flex", alignItems: "center", gap: 12, textAlign: "left", cursor: "pointer" }}
                onClick={() => setSelected(p)}
              >
                {p.primary_image && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={p.primary_image}
                    alt=""
                    style={{ width: 44, height: 44, borderRadius: "var(--radius-xs)", objectFit: "cover", flexShrink: 0 }}
                  />
                )}
                <div>
                  <b>{getLocalizedValue(p.name, lang)}</b>
                  <div className="text-muted" style={{ fontSize: "var(--fs-xs)" }}>
                    {p.brand} &middot; {formatPrice(p.price)}
                  </div>
                </div>
              </button>
            ))}
          </div>
        </div>
      ) : (
        <form style={{ display: "flex", flexDirection: "column", gap: 14 }} onSubmit={submit}>
          <div className="info-card" style={{ display: "flex", alignItems: "center", gap: 12 }}>
            {selected.primary_image && (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={selected.primary_image}
                alt=""
                style={{ width: 44, height: 44, borderRadius: "var(--radius-xs)", objectFit: "cover", flexShrink: 0 }}
              />
            )}
            <div style={{ flex: 1 }}>
              <b>{getLocalizedValue(selected.name, lang)}</b>
              <div className="text-muted" style={{ fontSize: "var(--fs-xs)" }}>{selected.brand}</div>
            </div>
            <button type="button" className="btn btn--ghost btn--sm" onClick={() => setSelected(null)}>
              {lang === "en" ? "Change" : "Изменить"}
            </button>
          </div>

          <div className="field">
            <label>SKU</label>
            <input required value={form.sku} onChange={(e) => set("sku", e.target.value)} />
          </div>
          <div style={{ display: "flex", gap: 12 }}>
            <div className="field" style={{ flex: 1 }}>
              <label>{lang === "en" ? "Price" : "Цена"}</label>
              <input type="number" min="0" step="0.01" required placeholder="50000" value={form.price} onChange={(e) => set("price", e.target.value)} />
            </div>
            <div className="field" style={{ flex: 1 }}>
              <label>{lang === "en" ? "Old price" : "Старая цена"}</label>
              <input type="number" min="0" step="0.01" placeholder="65000" value={form.oldPrice} onChange={(e) => set("oldPrice", e.target.value)} />
            </div>
          </div>
          <div style={{ display: "flex", gap: 12 }}>
            <div className="field" style={{ flex: 1 }}>
              <label>{lang === "en" ? "Delivery, days" : "Доставка, дней"}</label>
              <input type="number" min="0" required value={form.deliveryDays} onChange={(e) => set("deliveryDays", e.target.value)} />
            </div>
            <div className="field" style={{ flex: 1 }}>
              <label>{lang === "en" ? "Stock" : "Количество"}</label>
              <input type="number" min="0" required placeholder="20" value={form.stock} onChange={(e) => set("stock", e.target.value)} />
            </div>
          </div>
          <button type="submit" className="btn btn--primary btn--block btn--lg" disabled={saving}>
            {lang === "en" ? "Add offer" : "Добавить предложение"}
          </button>
        </form>
      )}
    </Modal>
  );
}

"use client";

import { useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";
import { getSellerInventory, updateSellerInventory } from "@/lib/api/sellerInventory";
import { getLocalizedValue } from "@/lib/api/adapters";

/** Stage 7: real available_quantity/reserved_quantity from
 * GET /sellers/:id/inventory — no fabricated "incoming shipment" column
 * (the backend has no such concept). Editing sets the new absolute
 * available_quantity (Stage 7 §11). */
export default function SellerInventory() {
  const { lang } = useLanguage();
  const { showToast } = useToast();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [drafts, setDrafts] = useState({});
  const [savingId, setSavingId] = useState(null);

  function refresh() {
    return getSellerInventory()
      .then(setItems)
      .catch(() => setItems([]));
  }

  useEffect(() => {
    refresh().finally(() => setLoading(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function save(offerId) {
    const draft = drafts[offerId];
    const value = Number(draft);
    if (!Number.isInteger(value) || value < 0) {
      showToast(lang === "en" ? "Stock must be a whole number ≥ 0." : "Остаток должен быть целым числом ≥ 0.", "warn", "⚠");
      return;
    }
    setSavingId(offerId);
    try {
      await updateSellerInventory(offerId, value);
      showToast(lang === "en" ? "Stock updated" : "Остаток обновлён", "success", "✓");
      setDrafts((d) => {
        const next = { ...d };
        delete next[offerId];
        return next;
      });
      await refresh();
    } catch (err) {
      showToast(err?.message || (lang === "en" ? "Couldn't update stock." : "Не удалось обновить остаток."), "warn", "⚠");
    } finally {
      setSavingId(null);
    }
  }

  return (
    <div className="data-table-wrap">
      <table className="data-table">
        <thead>
          <tr>
            <th>SKU</th>
            <th>{lang === "en" ? "Product" : "Товар"}</th>
            <th>{lang === "en" ? "Available" : "Доступно"}</th>
            <th>{lang === "en" ? "Reserved" : "Зарезервировано"}</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {loading ? null : !items.length ? (
            <tr>
              <td colSpan={5}>
                <div className="empty-state">
                  <div className="empty-state__icon">📦</div>
                  <h3>{lang === "en" ? "No inventory yet" : "Склад пуст"}</h3>
                </div>
              </td>
            </tr>
          ) : (
            items.map((it) => {
              const draft = drafts[it.offer_id];
              return (
                <tr key={it.offer_id}>
                  <td>{it.sku}</td>
                  <td>{getLocalizedValue(it.product_name, lang)}</td>
                  <td>
                    <input
                      type="number"
                      min="0"
                      style={{ width: 90 }}
                      value={draft !== undefined ? draft : it.available_quantity}
                      onChange={(e) => setDrafts((d) => ({ ...d, [it.offer_id]: e.target.value }))}
                    />
                    {it.is_low_stock && draft === undefined && (
                      <span className="badge badge--danger" style={{ marginLeft: 8 }}>
                        {lang === "en" ? "Low" : "Мало"}
                      </span>
                    )}
                  </td>
                  <td>{it.reserved_quantity}</td>
                  <td>
                    <button
                      className="btn btn--outline btn--sm"
                      disabled={draft === undefined || savingId === it.offer_id}
                      onClick={() => save(it.offer_id)}
                    >
                      {lang === "en" ? "Save" : "Сохранить"}
                    </button>
                  </td>
                </tr>
              );
            })
          )}
        </tbody>
      </table>
    </div>
  );
}

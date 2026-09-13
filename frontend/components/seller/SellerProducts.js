"use client";

import { useCallback, useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";
import { getSellerOffers, setSellerOfferStatus } from "@/lib/api/sellerOffers";
import { getLocalizedValue } from "@/lib/api/adapters";
import { formatPrice } from "@/lib/currency";
import AddOfferModal from "@/components/seller/AddOfferModal";
import EditOfferModal from "@/components/seller/EditOfferModal";

/** Stage 7: replaces the Stage 4 mock product table with the seller's real
 * seller_offers (list/add/edit/activate-deactivate) — no localStorage. */
export default function SellerProducts() {
  const { lang } = useLanguage();
  const { showToast } = useToast();
  const [offers, setOffers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [addOpen, setAddOpen] = useState(false);
  const [editing, setEditing] = useState(null);

  const refresh = useCallback(() => {
    return getSellerOffers({ search: search || undefined, limit: 100 })
      .then(({ items }) => setOffers(items))
      .catch(() => setOffers([]));
  }, [search]);

  useEffect(() => {
    setLoading(true);
    refresh().finally(() => setLoading(false));
  }, [refresh]);

  async function toggleStatus(offer) {
    try {
      await setSellerOfferStatus(offer.id, !offer.is_active);
      showToast(
        offer.is_active
          ? (lang === "en" ? "Offer deactivated" : "Предложение деактивировано")
          : (lang === "en" ? "Offer activated" : "Предложение активировано"),
        "info",
        offer.is_active ? "⏸" : "✓"
      );
      await refresh();
    } catch (err) {
      showToast(err?.message || (lang === "en" ? "Couldn't update status." : "Не удалось изменить статус."), "warn", "⚠");
    }
  }

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", gap: 10, marginBottom: 14, flexWrap: "wrap" }}>
        <input
          style={{ maxWidth: 280 }}
          placeholder={lang === "en" ? "Search offers..." : "Поиск предложений..."}
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <button className="btn btn--primary" onClick={() => setAddOpen(true)}>
          + {lang === "en" ? "Add offer" : "Добавить предложение"}
        </button>
      </div>
      <div className="data-table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>{lang === "en" ? "Photo" : "Фото"}</th>
              <th>SKU</th>
              <th>{lang === "en" ? "Name" : "Название"}</th>
              <th>{lang === "en" ? "Price" : "Цена"}</th>
              <th>{lang === "en" ? "Stock" : "Остаток"}</th>
              <th>{lang === "en" ? "Status" : "Статус"}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {loading ? null : !offers.length ? (
              <tr>
                <td colSpan={7}>
                  <div className="empty-state">
                    <div className="empty-state__icon">📦</div>
                    <h3>{lang === "en" ? "No offers yet" : "Нет предложений"}</h3>
                  </div>
                </td>
              </tr>
            ) : (
              offers.map((o) => (
                <tr key={o.id}>
                  <td>
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    {o.primary_image && <img className="dt-thumb" src={o.primary_image} alt="" />}
                  </td>
                  <td>{o.sku}</td>
                  <td>{getLocalizedValue(o.product_name, lang)}</td>
                  <td>{formatPrice(o.price)}</td>
                  <td>
                    {o.is_low_stock ? (
                      <span className="badge badge--danger">{lang === "en" ? "Left" : "Осталось"} {o.available_quantity}</span>
                    ) : (
                      o.available_quantity
                    )}
                  </td>
                  <td>
                    <span className={`status-pill ${o.is_active ? "status-pill--done" : "status-pill--cancel"}`}>
                      {o.is_active ? (lang === "en" ? "Active" : "Активен") : (lang === "en" ? "Inactive" : "Неактивен")}
                    </span>
                  </td>
                  <td className="row-actions">
                    <button aria-label={lang === "en" ? "Edit" : "Изменить"} onClick={() => setEditing(o)}>✎</button>
                    <button aria-label={lang === "en" ? "Toggle status" : "Переключить статус"} onClick={() => toggleStatus(o)}>
                      {o.is_active ? "⏸" : "▶"}
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <AddOfferModal open={addOpen} onClose={() => setAddOpen(false)} onCreated={refresh} />
      <EditOfferModal open={!!editing} offer={editing} onClose={() => setEditing(null)} onUpdated={refresh} />
    </div>
  );
}

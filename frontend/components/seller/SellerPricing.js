"use client";

import { useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { getSellerOffers } from "@/lib/api/sellerOffers";
import { getLocalizedValue } from "@/lib/api/adapters";
import { formatPrice } from "@/lib/currency";

export default function SellerPricing() {
  const { lang } = useLanguage();
  const [offers, setOffers] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getSellerOffers({ limit: 100 })
      .then(({ items }) => setOffers(items))
      .catch(() => setOffers([]))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="data-table-wrap">
      <table className="data-table">
        <thead>
          <tr>
            <th>{lang === "en" ? "Product" : "Товар"}</th>
            <th>{lang === "en" ? "Current price" : "Текущая цена"}</th>
            <th>{lang === "en" ? "Old price" : "Старая цена"}</th>
            <th>{lang === "en" ? "Discount" : "Скидка"}</th>
          </tr>
        </thead>
        <tbody>
          {loading ? null : !offers.length ? (
            <tr>
              <td colSpan={4}>
                <div className="empty-state">
                  <div className="empty-state__icon">🏷️</div>
                  <h3>{lang === "en" ? "No offers yet" : "Нет предложений"}</h3>
                </div>
              </td>
            </tr>
          ) : (
            offers.map((o) => {
              const price = Number(o.price);
              const oldPrice = o.old_price ? Number(o.old_price) : null;
              const discount = oldPrice && oldPrice > 0 ? Math.round((1 - price / oldPrice) * 100) : 0;
              return (
                <tr key={o.id}>
                  <td>{getLocalizedValue(o.product_name, lang)}</td>
                  <td>{formatPrice(o.price)}</td>
                  <td>{o.old_price ? formatPrice(o.old_price) : "—"}</td>
                  <td>{discount > 0 ? <span className="badge badge--sale">−{discount}%</span> : "—"}</td>
                </tr>
              );
            })
          )}
        </tbody>
      </table>
    </div>
  );
}

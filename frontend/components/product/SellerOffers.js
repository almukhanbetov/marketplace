"use client";

import { useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";
import { formatPrice } from "@/lib/currency";
import { deliveryLabel } from "@/lib/helpers";

export default function SellerOffers({ offers }) {
  const { t, lang } = useLanguage();
  const { showToast } = useToast();
  const [selected, setSelected] = useState(0);

  if (!offers.length) {
    return <p className="text-muted">{lang === "en" ? "No offers available for this product." : "Нет доступных предложений."}</p>;
  }

  return (
    <div>
      {offers.map((o, i) => (
        <div className={`offer-row ${i === selected ? "selected" : ""}`} key={o.offerId ?? i}>
          <div>
            <div className="offer-seller">{o.seller}</div>
            <div className="offer-meta">
              ★ {o.rating} &middot; {t("sellerLabel")}
            </div>
          </div>
          <div className="offer-delivery">🚚 {deliveryLabel(o.delivery, t, lang)}</div>
          <div className="offer-price">{formatPrice(o.price)}</div>
          <button
            className="btn btn--outline btn--sm"
            onClick={() => {
              setSelected(i);
              showToast(`${t("chooseSeller")}: ${o.seller}`, "success", "✓");
            }}
          >
            {t("chooseSeller")}
          </button>
        </div>
      ))}
    </div>
  );
}

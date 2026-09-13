"use client";

import Link from "next/link";
import { useLanguage } from "@/context/LanguageContext";
import { useCompare } from "@/context/CompareContext";
import { useCart } from "@/context/CartContext";
import { useProductsByIds } from "@/lib/useProductsByIds";
import { formatPrice } from "@/lib/currency";
import { deliveryLabel } from "@/lib/helpers";

export default function ComparePage() {
  const { t, lang } = useLanguage();
  const compare = useCompare();
  const cart = useCart();
  const items = useProductsByIds(compare.ids);

  const rows = [
    ["Изображение", (p) => (
      // eslint-disable-next-line @next/next/no-img-element
      <img src={p.image} style={{ width: 80, height: 80, objectFit: "cover", borderRadius: 10, margin: "0 auto" }} alt="" />
    )],
    ["Бренд", (p) => p.brand],
    [t("price"), (p) => <b style={{ fontSize: "var(--fs-md)" }}>{formatPrice(p.price)}</b>],
    ["Скидка", (p) => `−${p.discount}%`],
    [t("rating"), (p) => `★ ${p.rating} (${p.reviews})`],
    [t("seller"), (p) => p.seller],
    [t("delivery"), (p) => deliveryLabel(p.delivery, t, lang)],
    ["В наличии", (p) => `${p.availableQuantity} шт.`],
  ];

  return (
    <div className="container page-section--tight">
      <nav className="breadcrumbs" aria-label="Breadcrumb">
        <Link href="/">{t("home")}</Link>
        <span aria-hidden="true">/</span>
        <span>{t("compare")}</span>
      </nav>
      <h1 style={{ fontSize: "var(--fs-xl)", fontWeight: 800, marginBottom: 20 }}>{t("compare")}</h1>

      {!items.length ? (
        <div className="empty-state">
          <div className="empty-state__icon">⚖️</div>
          <h3>Список сравнения пуст</h3>
          <p>Добавьте товары к сравнению на карточке товара.</p>
          <Link href="/catalog" className="btn btn--primary btn--lg" style={{ marginTop: 10 }}>
            {t("startShopping")}
          </Link>
        </div>
      ) : (
        <div className="data-table-wrap">
          <table className="data-table compare-table">
            <tbody>
              <tr>
                <th>Товар</th>
                {items.map((p) => (
                  <th key={p.id}>
                    <Link href={`/product/${p.id}`} style={{ fontWeight: 700 }}>
                      {p.title}
                    </Link>
                  </th>
                ))}
              </tr>
              {rows.map(([label, fn]) => (
                <tr key={label}>
                  <td>{label}</td>
                  {items.map((p) => (
                    <td key={p.id}>{fn(p)}</td>
                  ))}
                </tr>
              ))}
              <tr>
                <td></td>
                {items.map((p) => (
                  <td key={p.id}>
                    <button className="btn btn--primary btn--sm" onClick={() => cart.addToCart(p, 1)}>
                      {t("addToCart")}
                    </button>
                  </td>
                ))}
              </tr>
              <tr>
                <td></td>
                {items.map((p) => (
                  <td key={p.id}>
                    <button className="btn btn--ghost btn--sm" onClick={() => compare.removeFromCompare(p.id)}>
                      ✕ Убрать
                    </button>
                  </td>
                ))}
              </tr>
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

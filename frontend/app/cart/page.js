"use client";

import Link from "next/link";
import { useLanguage } from "@/context/LanguageContext";
import { useCart } from "@/context/CartContext";
import { formatPrice } from "@/lib/currency";

export default function CartPage() {
  const { t, lang } = useLanguage();
  const cart = useCart();
  const groups = cart.groupBySeller();
  const totals = cart.getCartTotal();

  return (
    <div className="container page-section--tight">
      <nav className="breadcrumbs" aria-label="Breadcrumb">
        <Link href="/">{t("home")}</Link>
        <span aria-hidden="true">/</span>
        <span>{t("cart")}</span>
      </nav>
      <h1 style={{ fontSize: "var(--fs-xl)", fontWeight: 800, marginBottom: 20 }}>{t("yourCart")}</h1>

      {!groups.length ? (
        <div className="empty-state">
          <div className="empty-state__icon">🛒</div>
          <h3>{t("emptyCart")}</h3>
          <p>{t("emptyCartSub")}</p>
          <Link href="/catalog" className="btn btn--primary btn--lg" style={{ marginTop: 10 }}>
            {t("startShopping")}
          </Link>
        </div>
      ) : (
        <div className="layout-with-sidebar">
          <div>
            {groups.map((g) => (
              <div className="seller-group" key={g.seller}>
                <div className="seller-group-head">
                  <span>🏬</span>
                  <span>{g.seller}</span>
                  <span className="stars">★{g.rating}</span>
                </div>
                <div className="seller-group-body">
                  {g.items.map((i) => (
                    <div className="cart-line" key={i.id}>
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={i.product.image} alt={i.product.title} />
                      <div>
                        <Link href={`/product/${i.product.id}`} className="cart-line-title">
                          {i.product.title}
                        </Link>
                        <div className="cart-line-seller">
                          {formatPrice(i.product.price)} {lang === "en" ? "/ item" : "/ шт."}
                        </div>
                        <div className="qty-stepper">
                          <button onClick={() => cart.decreaseQuantity(i.id)}>−</button>
                          <span>{i.qty}</span>
                          <button onClick={() => cart.increaseQuantity(i.id)}>+</button>
                        </div>
                      </div>
                      <div>
                        <div className="cart-line-price">{formatPrice(i.product.price * i.qty)}</div>
                        <button className="cart-line-remove" onClick={() => cart.removeFromCart(i.id)}>
                          ✕ Удалить
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
                <div className="seller-group-foot">
                  <span>{t("subtotal")}</span>
                  <span>{formatPrice(g.items.reduce((s, i) => s + i.product.price * i.qty, 0))}</span>
                </div>
              </div>
            ))}
          </div>

          <aside className="sidebar-card">
            <h3 style={{ fontSize: "var(--fs-md)", fontWeight: 800, marginBottom: 14 }}>{t("total")}</h3>
            <div className="summary-row">
              <span>{t("items")}</span>
              <span>{formatPrice(totals.subtotal + totals.discount)}</span>
            </div>
            <div className="summary-row">
              <span>{t("discount")}</span>
              <span className="value--discount">−{formatPrice(totals.discount)}</span>
            </div>
            <div className="summary-row">
              <span>{t("shipping")}</span>
              <span>{totals.shipping ? formatPrice(totals.shipping) : t("free")}</span>
            </div>
            <div className="summary-row total">
              <span>{t("total")}</span>
              <span>{formatPrice(totals.total)}</span>
            </div>
            <Link href="/checkout" className="btn btn--primary btn--lg btn--block" style={{ marginTop: 14 }}>
              {t("checkout")}
            </Link>
          </aside>
        </div>
      )}
    </div>
  );
}

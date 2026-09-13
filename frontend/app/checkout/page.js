"use client";

import { Fragment, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useLanguage } from "@/context/LanguageContext";
import { useCart } from "@/context/CartContext";
import { useAuth } from "@/context/AuthContext";
import { useModal } from "@/context/ModalContext";
import { useToast } from "@/context/NotificationContext";
import { formatPrice } from "@/lib/currency";
import { getAddresses } from "@/lib/api/addresses";
import { createOrder } from "@/lib/api/orders";

const STEPS = [
  { n: 1, key: "recipient" },
  { n: 2, key: "deliveryMethod" },
  { n: 3, key: "payment" },
  { n: 4, key: "reviewOrder" },
];

const PAY_OPTIONS = [
  { id: "card", provider: "card", icon: "💳", label: "Банковская карта" },
  { id: "kaspi", provider: "kaspi_mock", icon: "🅺", label: "Kaspi" },
  { id: "apple", provider: "apple_pay_mock", icon: "🍏", label: "Apple Pay" },
  { id: "google", provider: "google_pay_mock", icon: "🅶", label: "Google Pay" },
];

// Maps backend error codes to a friendly message (Stage 6 §41) — never
// shows raw backend JSON/SQL to the customer.
function checkoutErrorMessage(err, lang) {
  const en = {
    INSUFFICIENT_STOCK: "One of your items no longer has enough stock.",
    OFFER_UNAVAILABLE: "One of the seller offers in your cart is no longer available.",
    CART_EMPTY: "Your cart is empty.",
    ADDRESS_NOT_FOUND: "Please choose a valid delivery address.",
    VALIDATION_ERROR: "Please check your order details and try again.",
  };
  const ru = {
    INSUFFICIENT_STOCK: "Недостаточно товара на складе для одной из позиций.",
    OFFER_UNAVAILABLE: "Предложение продавца больше недоступно.",
    CART_EMPTY: "Корзина пуста.",
    ADDRESS_NOT_FOUND: "Выберите корректный адрес доставки.",
    VALIDATION_ERROR: "Проверьте данные заказа и попробуйте снова.",
  };
  const table = lang === "en" ? en : ru;
  return table[err?.code] || (lang === "en" ? "Couldn't place the order. Please try again." : "Не удалось оформить заказ. Попробуйте снова.");
}

function newIdempotencyKey() {
  if (typeof crypto !== "undefined" && crypto.randomUUID) return crypto.randomUUID();
  return "idem-" + Date.now() + "-" + Math.random().toString(16).slice(2);
}

export default function CheckoutPage() {
  const { t, lang } = useLanguage();
  const cart = useCart();
  const { mounted, isAuthenticated } = useAuth();
  const { openModal } = useModal();
  const { showToast } = useToast();

  const [step, setStep] = useState(1);
  const [payMethod, setPayMethod] = useState("card");
  const [order, setOrder] = useState(null);
  const [placing, setPlacing] = useState(false);
  const [idempotencyKey, setIdempotencyKey] = useState(newIdempotencyKey);

  const [addresses, setAddresses] = useState([]);
  const [addressId, setAddressId] = useState(null);

  useEffect(() => {
    if (!isAuthenticated) return;
    getAddresses()
      .then((list) => {
        setAddresses(list);
        const def = list.find((a) => a.is_default) || list[0];
        if (def) setAddressId(def.id);
      })
      .catch(() => {});
  }, [isAuthenticated]);

  // The backend's Stage 6 order always uses free delivery (delivery_total
  // = "0.00" — no logistics backend yet, §26) — showing CartContext's
  // illustrative under-20000 shipping estimate here would display a total
  // that differs from what actually gets charged on submit, so checkout
  // (unlike the cart page/drawer, which keep their existing estimate)
  // shows the real backend-accurate total: subtotal only, free shipping.
  const cartTotals = cart.getCartTotal();
  const totals = { ...cartTotals, shipping: 0, total: cartTotals.subtotal };
  const groups = cart.groupBySeller();
  const selectedProvider = PAY_OPTIONS.find((p) => p.id === payMethod)?.provider || "card";

  function formatAddress(a) {
    const parts = [a.city, `${a.street} ${a.house}`];
    if (a.apartment) parts.push((lang === "en" ? "apt. " : "кв. ") + a.apartment);
    return parts.join(", ");
  }

  async function placeOrder() {
    if (!addressId) {
      showToast(lang === "en" ? "Please choose a delivery address." : "Выберите адрес доставки.", "warn", "⚠");
      return;
    }
    setPlacing(true);
    try {
      const created = await createOrder({ addressId, paymentProvider: selectedProvider }, idempotencyKey);
      setOrder(created);
      await cart.refreshCart();
      showToast(t("orderPlaced"), "success", "✅");
    } catch (err) {
      showToast(checkoutErrorMessage(err, lang), "warn", "⚠");
    } finally {
      setPlacing(false);
    }
  }

  if (order) {
    return (
      <div className="container page-section--tight">
        <div className="info-card" style={{ textAlign: "center", padding: "48px 24px", maxWidth: 640, margin: "0 auto" }}>
          <div style={{ fontSize: 52, marginBottom: 10 }}>✅</div>
          <h2 style={{ fontSize: "var(--fs-xl)", fontWeight: 800, marginBottom: 8 }}>{t("orderPlaced")}</h2>
          <p className="text-muted">№ {order.order_number}</p>
          <div style={{ display: "flex", justifyContent: "center", gap: 24, marginTop: 16, flexWrap: "wrap" }}>
            <div>
              <div className="text-muted" style={{ fontSize: "var(--fs-xs)" }}>{t("total")}</div>
              <b style={{ fontSize: "var(--fs-lg)" }}>{formatPrice(order.total)}</b>
            </div>
            <div>
              <div className="text-muted" style={{ fontSize: "var(--fs-xs)" }}>{lang === "en" ? "Items" : "Товаров"}</div>
              <b style={{ fontSize: "var(--fs-lg)" }}>{order.items.reduce((s, i) => s + i.quantity, 0)}</b>
            </div>
            <div>
              <div className="text-muted" style={{ fontSize: "var(--fs-xs)" }}>{t("orders")}</div>
              <b style={{ fontSize: "var(--fs-lg)" }}>{lang === "en" ? "Paid" : "Оплачен"}</b>
            </div>
          </div>
          <div style={{ display: "flex", gap: 10, justifyContent: "center", marginTop: 24, flexWrap: "wrap" }}>
            <Link href={`/profile/orders/${order.id}`} className="btn btn--primary btn--lg">
              {lang === "en" ? "View order" : "Посмотреть заказ"}
            </Link>
            <Link href="/catalog" className="btn btn--outline btn--lg">
              {t("startShopping")}
            </Link>
          </div>
        </div>
      </div>
    );
  }

  // Stage 9 §50: checkout requires an authenticated customer — the order's
  // user id comes exclusively from the auth context server-side, but a
  // logged-out visitor should never even see the checkout flow at all.
  if (mounted && !isAuthenticated) {
    return (
      <div className="container page-section--tight">
        <div className="empty-state">
          <div className="empty-state__icon">🔑</div>
          <h3>{t("loginRequired")}</h3>
          <button className="btn btn--primary btn--lg" style={{ marginTop: 10 }} onClick={() => openModal("login")}>
            {t("login")}
          </button>
        </div>
      </div>
    );
  }

  if (!cart.items.length) {
    return (
      <div className="container page-section--tight">
        <div className="empty-state">
          <div className="empty-state__icon">🛒</div>
          <h3>{t("emptyCart")}</h3>
          <Link href="/catalog" className="btn btn--primary btn--lg" style={{ marginTop: 10 }}>
            {t("startShopping")}
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="container page-section--tight">
      <nav className="breadcrumbs" aria-label="Breadcrumb">
        <Link href="/">{t("home")}</Link>
        <span aria-hidden="true">/</span>
        <Link href="/cart">{t("cart")}</Link>
        <span aria-hidden="true">/</span>
        <span>{t("checkout")}</span>
      </nav>

      <div className="checkout-step-nav">
        {STEPS.map((s, i) => (
          <Fragment key={s.n}>
            <div className={`checkout-step ${s.n === step ? "active" : ""} ${s.n < step ? "done" : ""}`}>
              <span className="num">{s.n}</span>
              <span className="step-label">{t(s.key)}</span>
            </div>
            {i < STEPS.length - 1 && <div className="checkout-step-sep" />}
          </Fragment>
        ))}
      </div>

      <div className="layout-with-sidebar">
        <div>
          {step === 1 && (
            <div className="info-card">
              <h3 style={{ fontSize: "var(--fs-md)", fontWeight: 800, marginBottom: 16 }}>{t("recipient")}</h3>
              <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
                <div className="field">
                  <label>{t("name")}</label>
                  <input defaultValue="Айгерим Ким" />
                </div>
                <div className="field">
                  <label>{t("phone")}</label>
                  <input defaultValue="+7 701 234 56 78" />
                </div>
                <div className="field">
                  <label>Email</label>
                  <input type="email" defaultValue="aigerim@example.com" />
                </div>
              </div>
              <button className="btn btn--primary" style={{ marginTop: 20 }} onClick={() => setStep(2)}>
                Продолжить →
              </button>
            </div>
          )}

          {step === 2 && (
            <div className="info-card">
              <h3 style={{ fontSize: "var(--fs-md)", fontWeight: 800, marginBottom: 16 }}>{t("deliveryMethod")}</h3>
              {addresses.length === 0 ? (
                <p className="text-muted">
                  {lang === "en" ? "No saved addresses yet — add one in your profile." : "Нет сохранённых адресов — добавьте адрес в профиле."}
                </p>
              ) : (
                addresses.map((a) => (
                  <div
                    className={`pay-option ${addressId === a.id ? "selected" : ""}`}
                    key={a.id}
                    onClick={() => setAddressId(a.id)}
                  >
                    <input type="radio" checked={addressId === a.id} readOnly />
                    <span className="po-icon">📍</span>
                    <div>
                      <b>{a.title || (lang === "en" ? "Address" : "Адрес")}</b>
                      <div className="text-muted" style={{ fontSize: "var(--fs-xs)" }}>{formatAddress(a)}</div>
                    </div>
                  </div>
                ))
              )}
              <div style={{ display: "flex", gap: 10, marginTop: 20 }}>
                <button className="btn btn--outline" onClick={() => setStep(1)}>← Назад</button>
                <button className="btn btn--primary" disabled={!addressId} onClick={() => setStep(3)}>Продолжить →</button>
              </div>
            </div>
          )}

          {step === 3 && (
            <div className="info-card">
              <h3 style={{ fontSize: "var(--fs-md)", fontWeight: 800, marginBottom: 16 }}>{t("payment")}</h3>
              {PAY_OPTIONS.map((opt) => (
                <div
                  className={`pay-option ${payMethod === opt.id ? "selected" : ""}`}
                  key={opt.id}
                  onClick={() => setPayMethod(opt.id)}
                >
                  <input type="radio" checked={payMethod === opt.id} readOnly />
                  <span className="po-icon">{opt.icon}</span>
                  <b>{opt.label}</b>
                </div>
              ))}
              <div style={{ display: "flex", gap: 10, marginTop: 8 }}>
                <div className="field" style={{ flex: 1 }}>
                  <label>Номер карты</label>
                  <input placeholder="4400 0000 0000 0000" maxLength={19} />
                </div>
              </div>
              <div style={{ display: "flex", gap: 10 }}>
                <div className="field" style={{ flex: 1 }}>
                  <label>Срок действия</label>
                  <input placeholder="MM/YY" maxLength={5} />
                </div>
                <div className="field" style={{ flex: 1 }}>
                  <label>CVC</label>
                  <input placeholder="•••" maxLength={3} />
                </div>
              </div>
              <div style={{ display: "flex", gap: 10, marginTop: 20 }}>
                <button className="btn btn--outline" onClick={() => setStep(2)}>← Назад</button>
                <button className="btn btn--primary" onClick={() => setStep(4)}>Продолжить →</button>
              </div>
            </div>
          )}

          {step === 4 && (
            <div className="info-card">
              <h3 style={{ fontSize: "var(--fs-md)", fontWeight: 800, marginBottom: 16 }}>{t("reviewOrder")}</h3>
              <div>
                {groups.map((g) => (
                  <div style={{ marginBottom: 14 }} key={g.seller}>
                    <div style={{ fontWeight: 700, fontSize: "var(--fs-sm)", marginBottom: 6 }}>🏬 {g.seller}</div>
                    {g.items.map((i) => (
                      <div className="cart-line" style={{ padding: "8px 0" }} key={i.id}>
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img src={i.product.image} alt="" />
                        <div>
                          <div className="cart-line-title">{i.product.title}</div>
                          <div className="text-muted" style={{ fontSize: "var(--fs-xs)" }}>× {i.qty}</div>
                        </div>
                        <div className="cart-line-price">{formatPrice(i.product.price * i.qty)}</div>
                      </div>
                    ))}
                  </div>
                ))}
              </div>
              <div style={{ display: "flex", gap: 10, marginTop: 20 }}>
                <button className="btn btn--outline" onClick={() => setStep(3)} disabled={placing}>← Назад</button>
                <button className="btn btn--accent btn--lg" onClick={placeOrder} disabled={placing}>
                  {placing ? (lang === "en" ? "Placing order…" : "Оформляем…") : t("placeOrder")}
                </button>
              </div>
            </div>
          )}
        </div>

        <aside className="sidebar-card">
          <h3 style={{ fontSize: "var(--fs-md)", fontWeight: 800, marginBottom: 14 }}>{t("total")}</h3>
          <div className="summary-row">
            <span>{t("items")} ({cart.items.reduce((s, i) => s + i.qty, 0)})</span>
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
        </aside>
      </div>
    </div>
  );
}

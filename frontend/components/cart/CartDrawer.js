"use client";

import Link from "next/link";
import Drawer from "@/components/ui/Drawer";
import { useCart } from "@/context/CartContext";
import { useLanguage } from "@/context/LanguageContext";
import { formatPrice } from "@/lib/currency";

export default function CartDrawer() {
  const cart = useCart();
  const { t } = useLanguage();
  const totals = cart.getCartTotal();

  return (
    <Drawer
      open={cart.drawerOpen}
      onClose={cart.closeDrawer}
      title={t("yourCart")}
      ariaLabel="Корзина"
      footer={
        <>
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
          <Link
            href="/checkout"
            className="btn btn--primary btn--block btn--lg"
            style={!cart.items.length ? { pointerEvents: "none", opacity: 0.5 } : undefined}
            onClick={cart.closeDrawer}
          >
            {t("checkout")}
          </Link>
        </>
      }
    >
      {!cart.items.length ? (
        <div className="empty-state">
          <div className="empty-state__icon">🛒</div>
          <h3>{t("emptyCart")}</h3>
          <p>{t("emptyCartSub")}</p>
        </div>
      ) : (
        cart.items.map((i) => {
          const p = i.product;
          if (!p) return null;
          return (
            <div className="cart-line" key={i.id}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={p.image} alt={p.title} />
              <div>
                <div className="cart-line-title">{p.title}</div>
                <div className="cart-line-seller">
                  {t("sellerLabel")}: {p.seller}
                </div>
                <div className="qty-stepper">
                  <button aria-label="-" onClick={() => cart.decreaseQuantity(i.id)}>
                    −
                  </button>
                  <span>{i.qty}</span>
                  <button aria-label="+" onClick={() => cart.increaseQuantity(i.id)}>
                    +
                  </button>
                </div>
              </div>
              <div>
                <div className="cart-line-price">{formatPrice(p.price * i.qty)}</div>
                <button className="cart-line-remove" onClick={() => cart.removeFromCart(i.id)}>
                  ✕
                </button>
              </div>
            </div>
          );
        })
      )}
    </Drawer>
  );
}

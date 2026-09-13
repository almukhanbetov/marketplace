"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import Modal from "@/components/ui/Modal";
import { useModal } from "@/context/ModalContext";
import { useLanguage } from "@/context/LanguageContext";
import { useCart } from "@/context/CartContext";
import { getProduct } from "@/lib/api/products";
import { adaptProductDetail } from "@/lib/api/adapters";
import { formatPrice } from "@/lib/currency";
import { deliveryLabel } from "@/lib/helpers";
import { addRecentlyViewed } from "@/lib/useRecentlyViewed";

export default function QuickViewModal() {
  const { activeModal, modalData, closeModal } = useModal();
  const { t, lang } = useLanguage();
  const cart = useCart();
  const [product, setProduct] = useState(null);

  const open = activeModal === "quickview";
  const productId = open ? modalData?.productId : null;

  useEffect(() => {
    if (!productId) {
      setProduct(null);
      return;
    }
    let cancelled = false;
    getProduct(productId)
      .then((p) => {
        if (!cancelled) setProduct(adaptProductDetail(p, lang));
      })
      .catch(() => {
        if (!cancelled) setProduct(null);
      });
    return () => {
      cancelled = true;
    };
  }, [productId, lang]);

  useEffect(() => {
    if (open && product) addRecentlyViewed(product.id);
  }, [open, product]);

  if (!open || !product) return null;

  return (
    <Modal open={open} onClose={closeModal} title={t("quickView")} size="lg" labelledBy="qv-title">
      <div className="quickview-grid">
        <div className="quickview-img">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={product.image} alt={product.title} />
        </div>
        <div>
          <div className="pc-rating" style={{ marginBottom: 8 }}>
            <span className="stars">★★★★★</span>
            <b>{product.rating}</b> &middot; {product.reviews} {t("reviews")}
          </div>
          <div className="pc-brand">{product.brand}</div>
          <h3 style={{ fontSize: "var(--fs-lg)", fontWeight: 800, margin: "6px 0 12px" }}>{product.title}</h3>
          <div className="pc-price-row" style={{ marginBottom: 10 }}>
            <span className="pc-price" style={{ fontSize: "var(--fs-xl)" }}>
              {formatPrice(product.price)}
            </span>
            <span className="pc-price-old">{formatPrice(product.oldPrice)}</span>
            <span className="pc-discount">−{product.discount}%</span>
          </div>
          <div className="pc-delivery" style={{ marginBottom: 14 }}>
            🚚 {deliveryLabel(product.delivery, t, lang)}
          </div>
          <div style={{ display: "flex", gap: 10 }}>
            <button className="btn btn--primary btn--lg" onClick={() => cart.addToCart(product, 1)}>
              🛒 {t("addToCart")}
            </button>
            <Link href={`/product/${product.id}`} className="btn btn--outline btn--lg" onClick={closeModal}>
              {t("viewAll")}
            </Link>
          </div>
        </div>
      </div>
    </Modal>
  );
}

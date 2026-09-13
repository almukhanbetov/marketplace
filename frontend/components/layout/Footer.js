"use client";

import Link from "next/link";
import { useLanguage } from "@/context/LanguageContext";

export default function Footer() {
  const { t } = useLanguage();

  return (
    <footer className="site-footer">
      <div className="container">
        <div className="footer-grid">
          <div className="footer-col">
            <h5>Nova</h5>
            <a href="#">О компании</a>
            <a href="#">Карьера</a>
            <Link href="/seller-dashboard">Продавать на Nova</Link>
            <Link href="/admin">Admin</Link>
          </div>
          <div className="footer-col">
            <h5>{t("catalog")}</h5>
            <Link href="/catalog?cat=electronics">Электроника</Link>
            <Link href="/catalog?cat=fashion">Одежда</Link>
            <Link href="/catalog?cat=home">Дом</Link>
            <Link href="/catalog?cat=beauty">Красота</Link>
          </div>
          <div className="footer-col">
            <h5>{t("help")}</h5>
            <a href="#">Доставка и оплата</a>
            <a href="#">Возврат товара</a>
            <a href="#">Условия использования</a>
            <a href="#">Контакты</a>
          </div>
          <div className="footer-col">
            <h5>Покупателям</h5>
            <Link href="/cart">{t("cart")}</Link>
            <Link href="/favorites">{t("favorites")}</Link>
            <Link href="/compare">{t("compare")}</Link>
            <Link href="/profile">{t("myOrders")}</Link>
          </div>
          <div className="footer-col">
            <h5>Продавцам</h5>
            <Link href="/seller/1">Магазин TechStore</Link>
            <Link href="/seller-dashboard">Кабинет продавца</Link>
            <Link href="/seller-dashboard">Комиссия и тарифы</Link>
          </div>
        </div>
        <div className="footer-bottom">
          <span>© 2026 Nova Marketplace. Все права защищены.</span>
          <span>Next.js frontend · v2.0</span>
        </div>
      </div>
    </footer>
  );
}

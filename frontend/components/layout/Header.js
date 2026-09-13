"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useLanguage } from "@/context/LanguageContext";
import { useCart } from "@/context/CartContext";
import { useFavorites } from "@/context/FavoritesContext";
import LanguageSwitcher from "@/components/navigation/LanguageSwitcher";
import ThemeSwitcher from "@/components/navigation/ThemeSwitcher";
import MegaMenu from "@/components/navigation/MegaMenu";
import SearchBar from "@/components/search/SearchBar";
import UserMenu from "@/components/navigation/UserMenu";
import NotificationBell from "@/components/navigation/NotificationBell";

export default function Header() {
  const { t } = useLanguage();
  const cart = useCart();
  const favorites = useFavorites();
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    function onScroll() {
      setScrolled(window.scrollY > 4);
    }
    onScroll();
    document.addEventListener("scroll", onScroll, { passive: true });
    return () => document.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header className={`site-header ${scrolled ? "scrolled" : ""}`}>
      <div className="utility-bar">
        <div className="container">
          <div className="utility-left">
            <button type="button">📍 <span>{t("deliverTo")}</span></button>
            <a href="#">{t("pickupPoints")}</a>
            <a href="#">{t("forBusiness")}</a>
            <Link href="/seller-dashboard">{t("sellOnMp")}</Link>
            <a href="#">{t("help")}</a>
          </div>
          <div className="utility-right">
            <LanguageSwitcher />
            <ThemeSwitcher />
          </div>
        </div>
      </div>

      <div className="header-main">
        <div className="container">
          <Link href="/" className="logo">
            <span className="logo-mark">N</span>Nova<span>.</span>
          </Link>

          <MegaMenu />

          <SearchBar />

          <nav className="header-actions" aria-label="Действия пользователя">
            <NotificationBell />
            <UserMenu />

            <Link href="/profile" className="header-action hide-tablet">
              <span className="ha-icon">📦</span>
              <span className="ha-label">{t("orders")}</span>
            </Link>

            <Link href="/favorites" className="header-action">
              <span className="ha-icon">
                ♡
                <span className="ha-count" style={{ display: favorites.count > 0 ? "flex" : "none" }}>
                  {favorites.count}
                </span>
              </span>
              <span className="ha-label">{t("favorites")}</span>
            </Link>

            <button className={`header-action ${cart.bump ? "bump" : ""}`} onClick={cart.openDrawer}>
              <span className="ha-icon">
                🛒
                <span className="ha-count" style={{ display: cart.count > 0 ? "flex" : "none" }}>
                  {cart.count}
                </span>
              </span>
              <span className="ha-label">{t("cart")}</span>
            </button>
          </nav>
        </div>
      </div>
    </header>
  );
}

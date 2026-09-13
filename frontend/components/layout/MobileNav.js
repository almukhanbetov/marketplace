"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useLanguage } from "@/context/LanguageContext";
import { useCart } from "@/context/CartContext";
import { useFavorites } from "@/context/FavoritesContext";

export default function MobileNav() {
  const { t } = useLanguage();
  const pathname = usePathname();
  const cart = useCart();
  const favorites = useFavorites();

  const items = [
    { href: "/", icon: "🏠", key: "home" },
    { href: "/catalog", icon: "📂", key: "catalog" },
    { href: "/favorites", icon: "♡", key: "favorites", count: favorites.count },
    { href: "/cart", icon: "🛒", key: "cart", count: cart.count },
    { href: "/profile", icon: "👤", key: "profile" },
  ];

  return (
    <nav className="mobile-nav" aria-label="Мобильная навигация">
      {items.map((item) => (
        <Link key={item.href} href={item.href} className={pathname === item.href ? "active" : ""}>
          <span className="mn-icon">
            {item.icon}
            {item.count != null && (
              <span className="ha-count" style={{ display: item.count > 0 ? "flex" : "none" }}>
                {item.count}
              </span>
            )}
          </span>
          <span>{t(item.key)}</span>
        </Link>
      ))}
    </nav>
  );
}

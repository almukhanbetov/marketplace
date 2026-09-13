"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useLanguage } from "@/context/LanguageContext";
import { useAuth } from "@/context/AuthContext";
import { useModal } from "@/context/ModalContext";
import { useFavorites } from "@/context/FavoritesContext";
import { useTheme } from "@/context/ThemeContext";
import { useToast } from "@/context/NotificationContext";
import { formatPrice } from "@/lib/currency";
import { getOrders } from "@/lib/api/orders";
import ProductGrid from "@/components/product/ProductGrid";
import AddressesSection from "@/components/profile/AddressesSection";

const STATUS_LABELS_RU = {
  new: "Новый", confirmed: "Подтверждён", paid: "Оплачен", processing: "Собирается",
  shipped: "Передан в доставку", delivered: "Доставлен", cancelled: "Отменён", returned: "Возврат",
};
const STATUS_LABELS_EN = {
  new: "New", confirmed: "Confirmed", paid: "Paid", processing: "Processing",
  shipped: "Shipped", delivered: "Delivered", cancelled: "Cancelled", returned: "Returned",
};
const STATUS_CLASS = {
  new: "status-pill--new", confirmed: "status-pill--progress", paid: "status-pill--progress", processing: "status-pill--progress",
  shipped: "status-pill--progress", delivered: "status-pill--done", cancelled: "status-pill--cancel", returned: "status-pill--cancel",
};

const SECTIONS = [
  { key: "overview", icon: "👤", labelKey: "profile" },
  { key: "orders", icon: "📦", labelKey: "orders" },
  { key: "favorites", icon: "♡", labelKey: "favorites" },
  { key: "addresses", icon: "📍", label: "Адреса" },
  { key: "payments", icon: "💳", label: "Платежи" },
  { key: "reviews", icon: "⭐", labelKey: "reviews" },
  { key: "notifications", icon: "🔔", labelKey: "notifications" },
  { key: "settings", icon: "⚙️", labelKey: "settings" },
];

const MOCK_MY_REVIEWS = [
  { product: "iPhone 17 Pro 256GB", rating: 5, text: "Отличный флагман, камера просто космос. Рекомендую!" },
  { product: "Робот-пылесос CleanBot X9", rating: 4, text: "Хорошо убирает, но иногда застревает под мебелью." },
];

export default function ProfilePage() {
  const { t, lang, setLang } = useLanguage();
  const { user, mounted, isAuthenticated } = useAuth();
  const { openModal } = useModal();
  const favorites = useFavorites();
  const { theme, apply } = useTheme();
  const { showToast } = useToast();

  const [section, setSection] = useState("overview");
  const [orders, setOrders] = useState([]);
  const [ordersLoading, setOrdersLoading] = useState(true);
  const [settingsLang, setSettingsLang] = useState(lang);
  const [settingsTheme, setSettingsTheme] = useState(theme);

  useEffect(() => {
    if (!isAuthenticated) {
      setOrdersLoading(false);
      return;
    }
    getOrders()
      .then(setOrders)
      .catch(() => setOrders([]))
      .finally(() => setOrdersLoading(false));
  }, [isAuthenticated]);

  useEffect(() => setSettingsLang(lang), [lang]);
  useEffect(() => setSettingsTheme(theme), [theme]);

  const favoriteProducts = favorites.items;
  const statusLabels = lang === "en" ? STATUS_LABELS_EN : STATUS_LABELS_RU;

  // Stage 9 §45: /profile is guarded client-side for UX — the real
  // security boundary is the backend rejecting /me/* and /auth/me for an
  // unauthenticated caller regardless of what this page renders.
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

  return (
    <div className="container page-section--tight">
      <nav className="breadcrumbs" aria-label="Breadcrumb">
        <Link href="/">{t("home")}</Link>
        <span aria-hidden="true">/</span>
        <span>{t("profile")}</span>
      </nav>

      <div className="dash-shell" style={{ minHeight: "auto" }}>
        <aside
          className="dash-sidebar"
          style={{ position: "static", height: "auto", borderRight: "none", background: "transparent", padding: "0 20px 0 0" }}
        >
          <div className="sidebar-card">
            <div style={{ display: "flex", alignItems: "center", gap: 12, paddingBottom: 16, marginBottom: 8, borderBottom: "1px solid var(--border)" }}>
              <div className="review-avatar" style={{ width: 48, height: 48, fontSize: 18 }}>
                {(user?.full_name || "АК").slice(0, 2).toUpperCase()}
              </div>
              <div>
                <div style={{ fontWeight: 700 }}>{user?.full_name || ""}</div>
                <div className="text-muted" style={{ fontSize: "var(--fs-xs)" }}>{user?.email || user?.phone || ""}</div>
              </div>
            </div>
            {SECTIONS.map((s) => (
              <button
                key={s.key}
                className={`dash-nav-item ${section === s.key ? "active" : ""}`}
                onClick={() => setSection(s.key)}
              >
                <span className="dn-icon">{s.icon}</span>
                <span>{s.labelKey ? t(s.labelKey) : s.label}</span>
              </button>
            ))}
          </div>
        </aside>

        <div className="dash-main" style={{ padding: 0 }}>
          {section === "overview" && (
            <div className="info-card">
              <h3 style={{ fontSize: "var(--fs-md)", fontWeight: 800, marginBottom: 16 }}>{t("profile")}</h3>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14 }}>
                <div className="field"><label>{t("name")}</label><input defaultValue={user?.full_name || ""} /></div>
                <div className="field"><label>Email</label><input defaultValue={user?.email || ""} type="email" /></div>
                <div className="field"><label>{t("phone")}</label><input defaultValue={user?.phone || ""} /></div>
                <div className="field"><label>Дата рождения</label><input type="date" defaultValue="1996-04-12" /></div>
              </div>
              <button className="btn btn--primary" style={{ marginTop: 16 }} onClick={() => showToast(t("settingsSaved"), "success", "✓")}>
                Сохранить изменения
              </button>
            </div>
          )}

          {section === "orders" && (
            <div>
              {ordersLoading ? (
                <p className="text-muted">{lang === "en" ? "Loading…" : "Загрузка…"}</p>
              ) : !orders.length ? (
                <div className="empty-state"><div className="empty-state__icon">📦</div><h3>Заказов пока нет</h3></div>
              ) : (
                orders.map((o) => (
                  <div className="order-card" key={o.id}>
                    <div className="order-card-head">
                      <div>
                        <div className="order-card-id">Заказ #{o.order_number}</div>
                        <div className="order-card-date">{new Date(o.created_at).toLocaleDateString(lang === "en" ? "en-US" : "ru-RU")}</div>
                      </div>
                      <span className={`status-pill ${STATUS_CLASS[o.status] || ""}`}>{statusLabels[o.status] || o.status}</span>
                    </div>
                    <div className="text-muted" style={{ fontSize: "var(--fs-sm)" }}>
                      {o.item_count} {lang === "en" ? "items" : "товара"}
                    </div>
                    <div className="order-card-foot">
                      <b>{formatPrice(o.total)}</b>
                      <Link href={`/profile/orders/${o.id}`} className="btn btn--outline btn--sm">
                        Подробнее
                      </Link>
                    </div>
                  </div>
                ))
              )}
            </div>
          )}

          {section === "favorites" && <ProductGrid products={favoriteProducts} />}

          {section === "addresses" && <AddressesSection />}

          {section === "payments" && (
            <div>
              <div className="info-card" style={{ marginBottom: 14, display: "flex", alignItems: "center", gap: 14 }}>
                <span style={{ fontSize: 24 }}>💳</span>
                <div><b>Visa •••• 4821</b><div className="text-muted" style={{ fontSize: "var(--fs-xs)" }}>Истекает 08/28</div></div>
              </div>
              <div className="info-card" style={{ display: "flex", alignItems: "center", gap: 14 }}>
                <span style={{ fontSize: 24 }}>🅺</span>
                <div><b>Kaspi Gold •••• 1190</b><div className="text-muted" style={{ fontSize: "var(--fs-xs)" }}>Привязана</div></div>
              </div>
              <button className="btn btn--outline" style={{ marginTop: 14 }}>+ Добавить карту</button>
            </div>
          )}

          {section === "reviews" && (
            <div>
              {MOCK_MY_REVIEWS.map((r, i) => (
                <div className="review-card" key={i}>
                  <div className="review-avatar">АК</div>
                  <div style={{ flex: 1 }}>
                    <div className="review-head">
                      <span className="review-name">{r.product}</span>
                      <span className="stars">{"★".repeat(r.rating)}{"☆".repeat(5 - r.rating)}</span>
                    </div>
                    <div className="review-text">{r.text}</div>
                  </div>
                </div>
              ))}
            </div>
          )}

          {section === "notifications" && (
            <div className="info-card">
              {[
                ["Статус заказа", true],
                ["Снижение цены на избранное", true],
                ["Акции и рассылки", false],
              ].map(([label, checked], i, arr) => (
                <div
                  key={label}
                  style={{
                    display: "flex", justifyContent: "space-between", alignItems: "center",
                    padding: "10px 0", borderBottom: i < arr.length - 1 ? "1px solid var(--border)" : "none",
                  }}
                >
                  <span>{label}</span>
                  <input type="checkbox" defaultChecked={checked} style={{ width: 20, height: 20, accentColor: "var(--accent)" }} />
                </div>
              ))}
            </div>
          )}

          {section === "settings" && (
            <div className="info-card">
              <h3 style={{ fontSize: "var(--fs-md)", fontWeight: 800, marginBottom: 16 }}>{t("settings")}</h3>
              <div className="field" style={{ marginBottom: 14 }}>
                <label>Язык интерфейса</label>
                <select value={settingsLang} onChange={(e) => setSettingsLang(e.target.value)}>
                  <option value="ru">Русский</option>
                  <option value="kk">Қазақша</option>
                  <option value="en">English</option>
                </select>
              </div>
              <div className="field" style={{ marginBottom: 14 }}>
                <label>Тема</label>
                <select value={settingsTheme} onChange={(e) => setSettingsTheme(e.target.value)}>
                  <option value="dark">Dark Premium</option>
                  <option value="vivid">Vivid</option>
                </select>
              </div>
              <button
                className="btn btn--primary"
                onClick={() => {
                  setLang(settingsLang);
                  apply(settingsTheme);
                  showToast(t("settingsSaved"), "success", "✓");
                }}
              >
                {t("settingsSaved")}
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

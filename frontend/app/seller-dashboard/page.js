"use client";

import { useState } from "react";
import { useAuth } from "@/context/AuthContext";
import { useModal } from "@/context/ModalContext";
import SellerSidebar from "@/components/seller/SellerSidebar";
import SellerStats from "@/components/seller/SellerStats";
import SellerProducts from "@/components/seller/SellerProducts";
import SellerOrders from "@/components/seller/SellerOrders";
import SellerInventory from "@/components/seller/SellerInventory";
import SellerPricing from "@/components/seller/SellerPricing";
import SellerFinance from "@/components/seller/SellerFinance";
import SellerAnalytics from "@/components/seller/SellerAnalytics";
import SellerReviews from "@/components/seller/SellerReviews";

const TITLES = {
  overview: "Dashboard", products: "Товары", orders: "Заказы", inventory: "Склад", pricing: "Цены",
  finance: "Финансы", analytics: "Аналитика", reviews: "Отзывы", messages: "Сообщения", ads: "Реклама", settings: "Настройки",
};

export default function SellerDashboardPage() {
  const [section, setSection] = useState("overview");
  const { user, mounted, role } = useAuth();
  const { openModal } = useModal();

  // Stage 9 §45/§47: client-side guard for UX only — the backend's
  // RequireRole("seller") + RequireActiveSeller are the real boundary
  // (every /api/v1/seller/* call 403s regardless of what this page shows).
  if (mounted && role !== "seller") {
    return (
      <div className="container page-section--tight">
        <div className="empty-state">
          <div className="empty-state__icon">🔑</div>
          <h3>{role ? "Доступно только продавцам" : "Войдите как продавец"}</h3>
          {!role && (
            <button className="btn btn--primary btn--lg" style={{ marginTop: 10 }} onClick={() => openModal("login")}>
              Войти
            </button>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="dash-shell">
      <SellerSidebar section={section} onSelect={setSection} />

      <div className="dash-main">
        <div className="section-head">
          <div>
            <h2>{TITLES[section]}</h2>
            <div className="section-sub">{user?.full_name} &middot; продавец на Nova</div>
          </div>
        </div>

        {section === "overview" && <SellerStats />}
        {section === "products" && <SellerProducts />}
        {section === "orders" && <SellerOrders />}
        {section === "inventory" && <SellerInventory />}
        {section === "pricing" && <SellerPricing />}
        {section === "finance" && <SellerFinance />}
        {section === "analytics" && <SellerAnalytics />}
        {section === "reviews" && <SellerReviews />}

        {section === "messages" && (
          <div>
            <div className="info-card" style={{ marginBottom: 10 }}>
              <b>Динара А.</b>
              <div className="text-muted" style={{ fontSize: "var(--fs-xs)" }}>Здравствуйте! Подскажите, есть ли товар в наличии в другом цвете?</div>
            </div>
            <div className="info-card">
              <b>Ерлан С.</b>
              <div className="text-muted" style={{ fontSize: "var(--fs-xs)" }}>Спасибо за быструю доставку, всё отлично!</div>
            </div>
          </div>
        )}

        {section === "ads" && (
          <div>
            <div className="stat-grid">
              <div className="stat-card"><span className="stat-label">Активные кампании</span><span className="stat-value">3</span></div>
              <div className="stat-card"><span className="stat-label">Показы</span><span className="stat-value">128 400</span></div>
              <div className="stat-card"><span className="stat-label">CTR</span><span className="stat-value">3.8%</span></div>
            </div>
            <button className="btn btn--primary" style={{ marginTop: 16 }}>+ Создать кампанию</button>
          </div>
        )}

        {section === "settings" && (
          <div className="info-card" style={{ maxWidth: 520 }}>
            <div className="field" style={{ marginBottom: 14 }}><label>Название магазина</label><input defaultValue="TechStore" /></div>
            <div className="field" style={{ marginBottom: 14 }}><label>Email для связи</label><input defaultValue="support@techstore.kz" /></div>
            <div className="field" style={{ marginBottom: 14 }}><label>Телефон</label><input defaultValue="+7 727 000 00 00" /></div>
            <button className="btn btn--primary">Сохранить</button>
          </div>
        )}
      </div>
    </div>
  );
}

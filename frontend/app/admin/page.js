"use client";

import { useState } from "react";
import { useAuth } from "@/context/AuthContext";
import { useModal } from "@/context/ModalContext";
import AdminSidebar from "@/components/admin/AdminSidebar";
import AdminOverview from "@/components/admin/AdminOverview";
import AdminUsers from "@/components/admin/AdminUsers";
import AdminSellers from "@/components/admin/AdminSellers";
import AdminProducts from "@/components/admin/AdminProducts";
import AdminCategories from "@/components/admin/AdminCategories";
import AdminOrders from "@/components/admin/AdminOrders";
import AdminPayments from "@/components/admin/AdminPayments";
import AdminCommissions from "@/components/admin/AdminCommissions";
import AdminPayouts from "@/components/admin/AdminPayouts";
import AdminReturns from "@/components/admin/AdminReturns";
import AdminReviews from "@/components/admin/AdminReviews";
import AdminPromotions from "@/components/admin/AdminPromotions";
import AdminAnalytics from "@/components/admin/AdminAnalytics";
import AdminSettings from "@/components/admin/AdminSettings";

const TITLES = {
  overview: "Overview", users: "Users", sellers: "Sellers", products: "Products", categories: "Categories",
  orders: "Orders", payments: "Payments", commissions: "Commissions", payouts: "Payouts", returns: "Returns",
  reviews: "Reviews", promotions: "Promotions", analytics: "Analytics", settings: "Settings",
};

const PANELS = {
  overview: AdminOverview, users: AdminUsers, sellers: AdminSellers, products: AdminProducts,
  categories: AdminCategories, orders: AdminOrders, payments: AdminPayments, commissions: AdminCommissions,
  payouts: AdminPayouts, returns: AdminReturns, reviews: AdminReviews, promotions: AdminPromotions,
  analytics: AdminAnalytics, settings: AdminSettings,
};

export default function AdminPage() {
  const [section, setSection] = useState("overview");
  const { mounted, role } = useAuth();
  const { openModal } = useModal();
  const ActivePanel = PANELS[section];

  // Stage 9 §46/§53: client-side guard for UX only — every /api/v1/admin/*
  // route already requires RequireAuth + RequireRole("admin") server-side.
  if (mounted && role !== "admin") {
    return (
      <div className="container page-section--tight">
        <div className="empty-state">
          <div className="empty-state__icon">🔑</div>
          <h3>{role ? "Доступно только администраторам" : "Войдите как администратор"}</h3>
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
      <AdminSidebar section={section} onSelect={setSection} />
      <div className="dash-main">
        <div className="section-head">
          <div>
            <h2>{TITLES[section]}</h2>
            <div className="section-sub">Nova Marketplace &middot; администрирование платформы</div>
          </div>
        </div>
        <ActivePanel />
      </div>
    </div>
  );
}

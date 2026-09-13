"use client";

import { useCallback, useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";
import { getAdminSellers, setAdminSellerStatus, setAdminSellerVerification } from "@/lib/api/adminSellers";
import AdminSellerDetailModal from "@/components/admin/AdminSellerDetailModal";

export default function AdminSellers() {
  const { lang } = useLanguage();
  const { showToast } = useToast();
  const [sellers, setSellers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [openSellerId, setOpenSellerId] = useState(null);

  const refresh = useCallback(() => {
    return getAdminSellers({ limit: 100 })
      .then(({ items }) => setSellers(items))
      .catch(() => setSellers([]));
  }, []);

  useEffect(() => {
    setLoading(true);
    refresh().finally(() => setLoading(false));
  }, [refresh]);

  async function toggleVerified(s) {
    try {
      await setAdminSellerVerification(s.id, !s.is_verified);
      showToast(
        s.is_verified ? (lang === "en" ? "Verification removed" : "Верификация снята") : (lang === "en" ? "Seller verified" : "Продавец верифицирован"),
        "success",
        "✓"
      );
      await refresh();
    } catch (err) {
      showToast(err?.message || (lang === "en" ? "Couldn't update verification." : "Не удалось изменить верификацию."), "warn", "⚠");
    }
  }

  async function toggleStatus(s) {
    try {
      await setAdminSellerStatus(s.id, !s.is_active);
      showToast(
        s.is_active ? (lang === "en" ? "Seller deactivated" : "Продавец деактивирован") : (lang === "en" ? "Seller activated" : "Продавец активирован"),
        "info",
        s.is_active ? "⏸" : "✓"
      );
      await refresh();
    } catch (err) {
      showToast(err?.message || (lang === "en" ? "Couldn't update status." : "Не удалось изменить статус."), "warn", "⚠");
    }
  }

  return (
    <div>
      <div className="data-table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>{lang === "en" ? "Seller" : "Продавец"}</th>
              <th>{lang === "en" ? "Verified" : "Верификация"}</th>
              <th>{lang === "en" ? "Rating" : "Рейтинг"}</th>
              <th>{lang === "en" ? "Offers" : "Предложения"}</th>
              <th>{lang === "en" ? "Status" : "Статус"}</th>
              <th>{lang === "en" ? "Created" : "Регистрация"}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {loading ? null : !sellers.length ? (
              <tr>
                <td colSpan={7}>
                  <div className="empty-state">
                    <div className="empty-state__icon">🏬</div>
                    <h3>{lang === "en" ? "No sellers found" : "Продавцы не найдены"}</h3>
                  </div>
                </td>
              </tr>
            ) : (
              sellers.map((s) => (
                <tr key={s.id}>
                  <td>{s.name}</td>
                  <td>
                    {s.is_verified ? (
                      <span className="status-pill status-pill--progress">{lang === "en" ? "Verified" : "Верифицирован"}</span>
                    ) : (
                      <span className="text-muted">—</span>
                    )}
                  </td>
                  <td>★ {s.rating.toFixed(1)} ({s.review_count})</td>
                  <td>{s.active_offer_count}</td>
                  <td>
                    <span className={`status-pill ${s.is_active ? "status-pill--done" : "status-pill--cancel"}`}>
                      {s.is_active ? (lang === "en" ? "Active" : "Активен") : (lang === "en" ? "Inactive" : "Неактивен")}
                    </span>
                  </td>
                  <td>{new Date(s.created_at).toLocaleDateString(lang === "en" ? "en-US" : "ru-RU")}</td>
                  <td className="row-actions">
                    <button aria-label={lang === "en" ? "View" : "Просмотр"} onClick={() => setOpenSellerId(s.id)}>👁</button>
                    <button aria-label={lang === "en" ? "Toggle verification" : "Переключить верификацию"} onClick={() => toggleVerified(s)}>
                      {s.is_verified ? "🎗️" : "☆"}
                    </button>
                    <button aria-label={lang === "en" ? "Toggle status" : "Переключить статус"} onClick={() => toggleStatus(s)}>
                      {s.is_active ? "⏸" : "▶"}
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <AdminSellerDetailModal sellerId={openSellerId} onClose={() => setOpenSellerId(null)} />
    </div>
  );
}

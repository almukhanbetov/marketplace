"use client";

import { useCallback, useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";
import { getAdminUsers, setAdminUserStatus } from "@/lib/api/adminUsers";

const ROLE_LABELS_RU = { customer: "Покупатель", seller: "Продавец", admin: "Админ" };
const ROLE_LABELS_EN = { customer: "Customer", seller: "Seller", admin: "Admin" };

/** Stage 8: real user table from GET /admin/users — never renders
 * password_hash (the backend never sends it at all). Deactivating a user
 * is admin STATE only in Stage 8: without authentication yet, it cannot
 * enforce login blocking — that arrives with Stage 9 auth. */
export default function AdminUsers() {
  const { lang } = useLanguage();
  const { showToast } = useToast();
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const roleLabels = lang === "en" ? ROLE_LABELS_EN : ROLE_LABELS_RU;

  const refresh = useCallback(() => {
    return getAdminUsers({ search: search || undefined, limit: 100 })
      .then(({ items }) => setUsers(items))
      .catch(() => setUsers([]));
  }, [search]);

  useEffect(() => {
    setLoading(true);
    refresh().finally(() => setLoading(false));
  }, [refresh]);

  async function toggleStatus(u) {
    try {
      await setAdminUserStatus(u.id, !u.is_active);
      showToast(
        u.is_active ? (lang === "en" ? "User deactivated" : "Пользователь деактивирован") : (lang === "en" ? "User activated" : "Пользователь активирован"),
        "info",
        u.is_active ? "⏸" : "✓"
      );
      await refresh();
    } catch (err) {
      showToast(err?.message || (lang === "en" ? "Couldn't update status." : "Не удалось изменить статус."), "warn", "⚠");
    }
  }

  return (
    <div>
      <div style={{ marginBottom: 14 }}>
        <input
          style={{ maxWidth: 320 }}
          placeholder={lang === "en" ? "Search by name, email, phone..." : "Поиск по имени, email, телефону..."}
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>
      <div className="data-table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>{lang === "en" ? "Name" : "Имя"}</th>
              <th>Email</th>
              <th>{lang === "en" ? "Phone" : "Телефон"}</th>
              <th>{lang === "en" ? "Role" : "Роль"}</th>
              <th>{lang === "en" ? "Status" : "Статус"}</th>
              <th>{lang === "en" ? "Created" : "Регистрация"}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {loading ? null : !users.length ? (
              <tr>
                <td colSpan={7}>
                  <div className="empty-state">
                    <div className="empty-state__icon">👥</div>
                    <h3>{lang === "en" ? "No users found" : "Пользователи не найдены"}</h3>
                  </div>
                </td>
              </tr>
            ) : (
              users.map((u) => (
                <tr key={u.id}>
                  <td>{u.full_name}</td>
                  <td>{u.email || "—"}</td>
                  <td>{u.phone || "—"}</td>
                  <td>{roleLabels[u.role] || u.role}</td>
                  <td>
                    <span className={`status-pill ${u.is_active ? "status-pill--done" : "status-pill--cancel"}`}>
                      {u.is_active ? (lang === "en" ? "Active" : "Активен") : (lang === "en" ? "Inactive" : "Неактивен")}
                    </span>
                  </td>
                  <td>{new Date(u.created_at).toLocaleDateString(lang === "en" ? "en-US" : "ru-RU")}</td>
                  <td className="row-actions">
                    <button aria-label={lang === "en" ? "Toggle status" : "Переключить статус"} onClick={() => toggleStatus(u)}>
                      {u.is_active ? "⏸" : "▶"}
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

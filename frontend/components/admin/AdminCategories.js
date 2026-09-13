"use client";

import { useCallback, useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";
import { getAdminCategories, setAdminCategoryStatus } from "@/lib/api/adminCategories";
import { getLocalizedValue } from "@/lib/api/adapters";
import AdminCategoryModal from "@/components/admin/AdminCategoryModal";

export default function AdminCategories() {
  const { lang } = useLanguage();
  const { showToast } = useToast();
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState(null);

  const refresh = useCallback(() => {
    return getAdminCategories()
      .then(setCategories)
      .catch(() => setCategories([]));
  }, []);

  useEffect(() => {
    setLoading(true);
    refresh().finally(() => setLoading(false));
  }, [refresh]);

  async function toggleStatus(c) {
    try {
      await setAdminCategoryStatus(c.id, !c.is_active);
      showToast(
        c.is_active ? (lang === "en" ? "Category deactivated" : "Категория деактивирована") : (lang === "en" ? "Category activated" : "Категория активирована"),
        "info",
        c.is_active ? "⏸" : "✓"
      );
      await refresh();
    } catch (err) {
      showToast(err?.message || (lang === "en" ? "Couldn't update status." : "Не удалось изменить статус."), "warn", "⚠");
    }
  }

  function parentName(c) {
    if (!c.parent_id) return "—";
    const parent = categories.find((p) => p.id === c.parent_id);
    return parent ? getLocalizedValue(parent.name, lang) : "—";
  }

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "flex-end", marginBottom: 14 }}>
        <button
          className="btn btn--primary"
          onClick={() => {
            setEditing(null);
            setModalOpen(true);
          }}
        >
          + {lang === "en" ? "Add category" : "Добавить категорию"}
        </button>
      </div>
      <div className="data-table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>{lang === "en" ? "Name" : "Название"}</th>
              <th>{lang === "en" ? "Parent" : "Родитель"}</th>
              <th>{lang === "en" ? "Children" : "Подкатегории"}</th>
              <th>{lang === "en" ? "Sort" : "Порядок"}</th>
              <th>{lang === "en" ? "Status" : "Статус"}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {loading ? null : !categories.length ? (
              <tr>
                <td colSpan={6}>
                  <div className="empty-state">
                    <div className="empty-state__icon">🗂️</div>
                    <h3>{lang === "en" ? "No categories yet" : "Нет категорий"}</h3>
                  </div>
                </td>
              </tr>
            ) : (
              categories.map((c) => (
                <tr key={c.id}>
                  <td>{getLocalizedValue(c.name, lang)}</td>
                  <td>{parentName(c)}</td>
                  <td>{c.child_count}</td>
                  <td>{c.sort_order}</td>
                  <td>
                    <span className={`status-pill ${c.is_active ? "status-pill--done" : "status-pill--cancel"}`}>
                      {c.is_active ? (lang === "en" ? "Active" : "Активна") : (lang === "en" ? "Inactive" : "Неактивна")}
                    </span>
                  </td>
                  <td className="row-actions">
                    <button
                      aria-label={lang === "en" ? "Edit" : "Изменить"}
                      onClick={() => {
                        setEditing(c);
                        setModalOpen(true);
                      }}
                    >
                      ✎
                    </button>
                    <button aria-label={lang === "en" ? "Toggle status" : "Переключить статус"} onClick={() => toggleStatus(c)}>
                      {c.is_active ? "⏸" : "▶"}
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <AdminCategoryModal open={modalOpen} category={editing} categories={categories} onClose={() => setModalOpen(false)} onSaved={refresh} />
    </div>
  );
}

"use client";

import { useCallback, useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";
import { getAdminProducts, getAdminProduct, setAdminProductStatus } from "@/lib/api/adminProducts";
import { getLocalizedValue } from "@/lib/api/adapters";
import AdminProductModal from "@/components/admin/AdminProductModal";

export default function AdminProducts() {
  const { lang } = useLanguage();
  const { showToast } = useToast();
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState(null);

  const refresh = useCallback(() => {
    return getAdminProducts({ search: search || undefined, limit: 100 })
      .then(({ items }) => setProducts(items))
      .catch(() => setProducts([]));
  }, [search]);

  useEffect(() => {
    setLoading(true);
    refresh().finally(() => setLoading(false));
  }, [refresh]);

  async function openEdit(p) {
    try {
      const detail = await getAdminProduct(p.id);
      setEditing(detail);
      setModalOpen(true);
    } catch (err) {
      showToast(err?.message || (lang === "en" ? "Couldn't load product." : "Не удалось загрузить товар."), "warn", "⚠");
    }
  }

  async function toggleStatus(p) {
    try {
      await setAdminProductStatus(p.id, !p.is_active);
      showToast(
        p.is_active ? (lang === "en" ? "Product deactivated" : "Товар деактивирован") : (lang === "en" ? "Product activated" : "Товар активирован"),
        "info",
        p.is_active ? "⏸" : "✓"
      );
      await refresh();
    } catch (err) {
      showToast(err?.message || (lang === "en" ? "Couldn't update status." : "Не удалось изменить статус."), "warn", "⚠");
    }
  }

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", gap: 10, marginBottom: 14, flexWrap: "wrap" }}>
        <input
          style={{ maxWidth: 280 }}
          placeholder={lang === "en" ? "Search products..." : "Поиск товаров..."}
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <button
          className="btn btn--primary"
          onClick={() => {
            setEditing(null);
            setModalOpen(true);
          }}
        >
          + {lang === "en" ? "Add product" : "Добавить товар"}
        </button>
      </div>
      <div className="data-table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>{lang === "en" ? "Photo" : "Фото"}</th>
              <th>{lang === "en" ? "Product" : "Товар"}</th>
              <th>{lang === "en" ? "Brand" : "Бренд"}</th>
              <th>{lang === "en" ? "Category" : "Категория"}</th>
              <th>{lang === "en" ? "Rating" : "Рейтинг"}</th>
              <th>{lang === "en" ? "Offers" : "Предложения"}</th>
              <th>{lang === "en" ? "Status" : "Статус"}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {loading ? null : !products.length ? (
              <tr>
                <td colSpan={8}>
                  <div className="empty-state">
                    <div className="empty-state__icon">📦</div>
                    <h3>{lang === "en" ? "No products found" : "Товары не найдены"}</h3>
                  </div>
                </td>
              </tr>
            ) : (
              products.map((p) => (
                <tr key={p.id}>
                  <td>
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    {p.primary_image && <img className="dt-thumb" src={p.primary_image} alt="" />}
                  </td>
                  <td>{getLocalizedValue(p.name, lang)}</td>
                  <td>{p.brand || "—"}</td>
                  <td>{getLocalizedValue(p.category?.name, lang)}</td>
                  <td>★ {p.rating.toFixed(1)} ({p.review_count})</td>
                  <td>{p.offer_count}</td>
                  <td>
                    <span className={`status-pill ${p.is_active ? "status-pill--done" : "status-pill--cancel"}`}>
                      {p.is_active ? (lang === "en" ? "Active" : "Активен") : (lang === "en" ? "Inactive" : "Неактивен")}
                    </span>
                  </td>
                  <td className="row-actions">
                    <button aria-label={lang === "en" ? "Edit" : "Изменить"} onClick={() => openEdit(p)}>✎</button>
                    <button aria-label={lang === "en" ? "Toggle status" : "Переключить статус"} onClick={() => toggleStatus(p)}>
                      {p.is_active ? "⏸" : "▶"}
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <AdminProductModal open={modalOpen} product={editing} onClose={() => setModalOpen(false)} onSaved={refresh} />
    </div>
  );
}

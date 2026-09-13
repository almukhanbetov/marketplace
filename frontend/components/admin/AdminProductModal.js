"use client";

import { useEffect, useState } from "react";
import Modal from "@/components/ui/Modal";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";
import { getAdminCategories } from "@/lib/api/adminCategories";
import { createAdminProduct, updateAdminProduct } from "@/lib/api/adminProducts";
import { getLocalizedValue } from "@/lib/api/adapters";

const EMPTY_FORM = {
  categoryId: "", brand: "",
  nameRu: "", nameKk: "", nameEn: "",
  descriptionRu: "", descriptionKk: "", descriptionEn: "",
  slug: "", isActive: true, imageUrls: "",
};

/** Stage 8 §13/§53: admin manages global catalog identity only — category,
 * brand, localized names/descriptions, slug, image URLs, status. Never
 * seller/price/stock (those belong to seller offers, Stage 7). */
export default function AdminProductModal({ open, product, onClose, onSaved }) {
  const { lang } = useLanguage();
  const { showToast } = useToast();
  const [categories, setCategories] = useState([]);
  const [form, setForm] = useState(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const isEdit = !!product;

  useEffect(() => {
    if (open) getAdminCategories().then(setCategories).catch(() => setCategories([]));
  }, [open]);

  useEffect(() => {
    if (product) {
      setForm({
        categoryId: String(product.category?.id || ""),
        brand: product.brand || "",
        nameRu: product.name?.ru || "", nameKk: product.name?.kk || "", nameEn: product.name?.en || "",
        descriptionRu: product.description?.ru || "", descriptionKk: product.description?.kk || "", descriptionEn: product.description?.en || "",
        slug: product.slug || "", isActive: product.is_active,
        imageUrls: (product.images || []).map((i) => i.url).join("\n"),
      });
    } else {
      setForm(EMPTY_FORM);
    }
  }, [product, open]);

  function set(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
  }

  async function submit(e) {
    e.preventDefault();
    if (!form.categoryId || !form.nameRu.trim() || !form.nameKk.trim() || !form.nameEn.trim() || !form.slug.trim()) {
      showToast(lang === "en" ? "Category, all three names and slug are required." : "Категория, все три названия и slug обязательны.", "warn", "⚠");
      return;
    }
    const images = form.imageUrls
      .split("\n")
      .map((u) => u.trim())
      .filter(Boolean)
      .map((url, i) => ({ url, is_primary: i === 0, sort_order: i }));

    setSaving(true);
    try {
      const input = {
        categoryId: Number(form.categoryId), brand: form.brand,
        nameRu: form.nameRu, nameKk: form.nameKk, nameEn: form.nameEn,
        descriptionRu: form.descriptionRu, descriptionKk: form.descriptionKk, descriptionEn: form.descriptionEn,
        slug: form.slug, isActive: form.isActive, images,
      };
      if (isEdit) {
        await updateAdminProduct(product.id, input);
        showToast(lang === "en" ? "Product updated" : "Товар обновлён", "success", "✓");
      } else {
        await createAdminProduct(input);
        showToast(lang === "en" ? "Product created" : "Товар создан", "success", "✓");
      }
      onSaved?.();
      onClose();
    } catch (err) {
      showToast(err?.message || (lang === "en" ? "Couldn't save the product." : "Не удалось сохранить товар."), "warn", "⚠");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={isEdit ? (lang === "en" ? "Edit product" : "Изменить товар") : (lang === "en" ? "Add product" : "Добавить товар")}
      labelledBy="admin-product-title"
      size="lg"
    >
      <form style={{ display: "flex", flexDirection: "column", gap: 14 }} onSubmit={submit}>
        <div style={{ display: "flex", gap: 12 }}>
          <div className="field" style={{ flex: 1 }}>
            <label>{lang === "en" ? "Category" : "Категория"}</label>
            <select value={form.categoryId} onChange={(e) => set("categoryId", e.target.value)}>
              <option value="">{lang === "en" ? "Select..." : "Выберите..."}</option>
              {categories.map((c) => (
                <option key={c.id} value={c.id}>{getLocalizedValue(c.name, lang)}</option>
              ))}
            </select>
          </div>
          <div className="field" style={{ flex: 1 }}>
            <label>{lang === "en" ? "Brand" : "Бренд"}</label>
            <input value={form.brand} onChange={(e) => set("brand", e.target.value)} />
          </div>
        </div>

        <div className="field">
          <label>{lang === "en" ? "Name (RU)" : "Название (RU)"}</label>
          <input required value={form.nameRu} onChange={(e) => set("nameRu", e.target.value)} />
        </div>
        <div className="field">
          <label>{lang === "en" ? "Name (KAZ)" : "Название (KAZ)"}</label>
          <input required value={form.nameKk} onChange={(e) => set("nameKk", e.target.value)} />
        </div>
        <div className="field">
          <label>{lang === "en" ? "Name (ENG)" : "Название (ENG)"}</label>
          <input required value={form.nameEn} onChange={(e) => set("nameEn", e.target.value)} />
        </div>

        <div className="field">
          <label>{lang === "en" ? "Description (RU)" : "Описание (RU)"}</label>
          <textarea value={form.descriptionRu} onChange={(e) => set("descriptionRu", e.target.value)} />
        </div>
        <div className="field">
          <label>{lang === "en" ? "Description (KAZ)" : "Описание (KAZ)"}</label>
          <textarea value={form.descriptionKk} onChange={(e) => set("descriptionKk", e.target.value)} />
        </div>
        <div className="field">
          <label>{lang === "en" ? "Description (ENG)" : "Описание (ENG)"}</label>
          <textarea value={form.descriptionEn} onChange={(e) => set("descriptionEn", e.target.value)} />
        </div>

        <div className="field">
          <label>Slug</label>
          <input required value={form.slug} onChange={(e) => set("slug", e.target.value)} />
        </div>

        <div className="field">
          <label>{lang === "en" ? "Image URLs (one per line, first = primary)" : "URL изображений (по одному на строку, первое = главное)"}</label>
          <textarea rows={3} value={form.imageUrls} onChange={(e) => set("imageUrls", e.target.value)} placeholder="https://..." />
        </div>

        <label style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <input type="checkbox" checked={form.isActive} onChange={(e) => set("isActive", e.target.checked)} />
          {lang === "en" ? "Active" : "Активен"}
        </label>

        <button type="submit" className="btn btn--primary btn--block btn--lg" disabled={saving}>
          {isEdit ? (lang === "en" ? "Save" : "Сохранить") : (lang === "en" ? "Create" : "Создать")}
        </button>
      </form>
    </Modal>
  );
}

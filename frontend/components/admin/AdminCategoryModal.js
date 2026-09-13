"use client";

import { useEffect, useState } from "react";
import Modal from "@/components/ui/Modal";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";
import { createAdminCategory, updateAdminCategory } from "@/lib/api/adminCategories";
import { getLocalizedValue } from "@/lib/api/adapters";

const EMPTY_FORM = { parentId: "", nameRu: "", nameKk: "", nameEn: "", slug: "", imageUrl: "", sortOrder: "0", isActive: true };

export default function AdminCategoryModal({ open, category, categories, onClose, onSaved }) {
  const { lang } = useLanguage();
  const { showToast } = useToast();
  const [form, setForm] = useState(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const isEdit = !!category;

  useEffect(() => {
    if (category) {
      setForm({
        parentId: category.parent_id ? String(category.parent_id) : "",
        nameRu: category.name?.ru || "", nameKk: category.name?.kk || "", nameEn: category.name?.en || "",
        slug: category.slug || "", imageUrl: category.image_url || "",
        sortOrder: String(category.sort_order ?? 0), isActive: category.is_active,
      });
    } else {
      setForm(EMPTY_FORM);
    }
  }, [category, open]);

  function set(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
  }

  async function submit(e) {
    e.preventDefault();
    if (!form.nameRu.trim() || !form.nameKk.trim() || !form.nameEn.trim() || !form.slug.trim()) {
      showToast(lang === "en" ? "All three names and slug are required." : "Все три названия и slug обязательны.", "warn", "⚠");
      return;
    }
    setSaving(true);
    try {
      const input = {
        parentId: form.parentId ? Number(form.parentId) : null,
        nameRu: form.nameRu, nameKk: form.nameKk, nameEn: form.nameEn,
        slug: form.slug, imageUrl: form.imageUrl, sortOrder: Number(form.sortOrder) || 0, isActive: form.isActive,
      };
      if (isEdit) {
        await updateAdminCategory(category.id, input);
        showToast(lang === "en" ? "Category updated" : "Категория обновлена", "success", "✓");
      } else {
        await createAdminCategory(input);
        showToast(lang === "en" ? "Category created" : "Категория создана", "success", "✓");
      }
      onSaved?.();
      onClose();
    } catch (err) {
      showToast(err?.message || (lang === "en" ? "Couldn't save the category." : "Не удалось сохранить категорию."), "warn", "⚠");
    } finally {
      setSaving(false);
    }
  }

  const parentOptions = (categories || []).filter((c) => !category || c.id !== category.id);

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={isEdit ? (lang === "en" ? "Edit category" : "Изменить категорию") : (lang === "en" ? "Add category" : "Добавить категорию")}
      labelledBy="admin-category-title"
    >
      <form style={{ display: "flex", flexDirection: "column", gap: 14 }} onSubmit={submit}>
        <div className="field">
          <label>{lang === "en" ? "Parent category" : "Родительская категория"}</label>
          <select value={form.parentId} onChange={(e) => set("parentId", e.target.value)}>
            <option value="">{lang === "en" ? "None (root category)" : "Нет (корневая категория)"}</option>
            {parentOptions.map((c) => (
              <option key={c.id} value={c.id}>{getLocalizedValue(c.name, lang)}</option>
            ))}
          </select>
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
          <label>Slug</label>
          <input required value={form.slug} onChange={(e) => set("slug", e.target.value)} />
        </div>
        <div style={{ display: "flex", gap: 12 }}>
          <div className="field" style={{ flex: 1 }}>
            <label>{lang === "en" ? "Image URL" : "URL изображения"}</label>
            <input value={form.imageUrl} onChange={(e) => set("imageUrl", e.target.value)} placeholder="https://..." />
          </div>
          <div className="field" style={{ flex: 1 }}>
            <label>{lang === "en" ? "Sort order" : "Порядок"}</label>
            <input type="number" value={form.sortOrder} onChange={(e) => set("sortOrder", e.target.value)} />
          </div>
        </div>
        <label style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <input type="checkbox" checked={form.isActive} onChange={(e) => set("isActive", e.target.checked)} />
          {lang === "en" ? "Active" : "Активна"}
        </label>
        <button type="submit" className="btn btn--primary btn--block btn--lg" disabled={saving}>
          {isEdit ? (lang === "en" ? "Save" : "Сохранить") : (lang === "en" ? "Create" : "Создать")}
        </button>
      </form>
    </Modal>
  );
}

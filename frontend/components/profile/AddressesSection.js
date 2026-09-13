"use client";

import { useEffect, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";
import { getAddresses, createAddress, updateAddress, setDefaultAddress, deleteAddress } from "@/lib/api/addresses";

const EMPTY_FORM = { title: "", city: "", street: "", house: "", apartment: "", postal_code: "" };

/** Backend-backed address book (Stage 5, migrated to /me/addresses in
 * Stage 9) — list/add/edit/delete/set default, no localStorage. */
export default function AddressesSection() {
  const { lang } = useLanguage();
  const { showToast } = useToast();
  const [addresses, setAddresses] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editingId, setEditingId] = useState(null); // null | "new" | <address id>
  const [form, setForm] = useState(EMPTY_FORM);
  const [saving, setSaving] = useState(false);

  function refresh() {
    return getAddresses()
      .then(setAddresses)
      .catch(() => setAddresses([]));
  }

  useEffect(() => {
    refresh().finally(() => setLoading(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function startCreate() {
    setForm(EMPTY_FORM);
    setEditingId("new");
  }

  function startEdit(addr) {
    setForm({
      title: addr.title || "",
      city: addr.city,
      street: addr.street,
      house: addr.house,
      apartment: addr.apartment || "",
      postal_code: addr.postal_code || "",
    });
    setEditingId(addr.id);
  }

  function setField(key, value) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  async function save() {
    if (!form.city.trim() || !form.street.trim() || !form.house.trim()) {
      showToast(lang === "en" ? "City, street and house are required." : "Город, улица и дом обязательны.", "warn", "⚠");
      return;
    }
    setSaving(true);
    try {
      if (editingId === "new") {
        await createAddress(form);
      } else {
        await updateAddress(editingId, form);
      }
      await refresh();
      setEditingId(null);
    } catch (err) {
      showToast(err?.message || (lang === "en" ? "Couldn't save address." : "Не удалось сохранить адрес."), "warn", "⚠");
    } finally {
      setSaving(false);
    }
  }

  async function handleSetDefault(id) {
    try {
      await setDefaultAddress(id);
      await refresh();
    } catch {
      showToast(lang === "en" ? "Couldn't set default address." : "Не удалось установить основной адрес.", "warn", "⚠");
    }
  }

  async function handleDelete(id) {
    try {
      await deleteAddress(id);
      await refresh();
    } catch {
      showToast(lang === "en" ? "Couldn't delete address." : "Не удалось удалить адрес.", "warn", "⚠");
    }
  }

  function formatAddress(a) {
    const parts = [a.city, `${a.street} ${a.house}`];
    if (a.apartment) parts.push((lang === "en" ? "apt. " : "кв. ") + a.apartment);
    return parts.join(", ");
  }

  if (loading) return null;

  return (
    <div>
      {addresses.map((a) => (
        <div className="info-card" style={{ marginBottom: 14 }} key={a.id}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 10, flexWrap: "wrap" }}>
            <div>
              <b>{a.title || (lang === "en" ? "Address" : "Адрес")}</b>
              <div className="text-muted" style={{ fontSize: "var(--fs-xs)", marginTop: 4 }}>
                {formatAddress(a)}
              </div>
            </div>
            <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
              {a.is_default ? (
                <span className="badge badge--success">{lang === "en" ? "Default" : "Основной"}</span>
              ) : (
                <button className="btn btn--ghost btn--sm" onClick={() => handleSetDefault(a.id)}>
                  {lang === "en" ? "Set default" : "Сделать основным"}
                </button>
              )}
              <button className="btn btn--outline btn--sm" onClick={() => startEdit(a)}>
                {lang === "en" ? "Edit" : "Изменить"}
              </button>
              <button className="btn btn--ghost btn--sm" onClick={() => handleDelete(a.id)} aria-label="Delete">
                ✕
              </button>
            </div>
          </div>
        </div>
      ))}

      {editingId !== null ? (
        <div className="info-card" style={{ marginBottom: 14 }}>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14 }}>
            <div className="field">
              <label>{lang === "en" ? "Label" : "Название"}</label>
              <input value={form.title} onChange={(e) => setField("title", e.target.value)} />
            </div>
            <div className="field">
              <label>{lang === "en" ? "City" : "Город"} *</label>
              <input value={form.city} onChange={(e) => setField("city", e.target.value)} />
            </div>
            <div className="field">
              <label>{lang === "en" ? "Street" : "Улица"} *</label>
              <input value={form.street} onChange={(e) => setField("street", e.target.value)} />
            </div>
            <div className="field">
              <label>{lang === "en" ? "House" : "Дом"} *</label>
              <input value={form.house} onChange={(e) => setField("house", e.target.value)} />
            </div>
            <div className="field">
              <label>{lang === "en" ? "Apartment" : "Квартира"}</label>
              <input value={form.apartment} onChange={(e) => setField("apartment", e.target.value)} />
            </div>
            <div className="field">
              <label>{lang === "en" ? "Postal code" : "Индекс"}</label>
              <input value={form.postal_code} onChange={(e) => setField("postal_code", e.target.value)} />
            </div>
          </div>
          <div style={{ display: "flex", gap: 10, marginTop: 16 }}>
            <button className="btn btn--primary" disabled={saving} onClick={save}>
              {lang === "en" ? "Save" : "Сохранить"}
            </button>
            <button className="btn btn--outline" onClick={() => setEditingId(null)}>
              {lang === "en" ? "Cancel" : "Отмена"}
            </button>
          </div>
        </div>
      ) : (
        <button className="btn btn--outline" onClick={startCreate}>
          + {lang === "en" ? "Add address" : "Добавить адрес"}
        </button>
      )}
    </div>
  );
}

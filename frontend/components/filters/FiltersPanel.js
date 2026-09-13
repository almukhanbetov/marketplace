"use client";

import { useLanguage } from "@/context/LanguageContext";
import { getLocalizedValue } from "@/lib/api/adapters";

const ratingOptions = [4.5, 4, 3.5];

// The backend only accepts a single category/brand/seller value per
// request (Stage 3 §products?category=&brand=&seller=) — these three
// filter groups are single-select even though they're styled as
// checkboxes, matching the "rating" group's existing radio-like behaviour.
const EXCLUSIVE_KEYS = new Set(["cat", "brand", "seller"]);

function CheckboxGroup({ title, items, selected, onToggle }) {
  return (
    <div className="filter-group">
      <h4>{title}</h4>
      {items.map((it) => (
        <label className="filter-check" key={it.value}>
          <input type="checkbox" checked={selected.includes(it.value)} onChange={() => onToggle(it.value)} />
          <span>{it.label}</span>
        </label>
      ))}
    </div>
  );
}

export default function FiltersPanel({ state, setState, categories = [], sellers = [], brands = [] }) {
  const { t, lang } = useLanguage();

  function toggleIn(key, value) {
    setState((prev) => {
      if (EXCLUSIVE_KEYS.has(key)) {
        const already = prev[key].includes(value);
        return { ...prev, [key]: already ? [] : [value] };
      }
      return {
        ...prev,
        [key]: prev[key].includes(value) ? prev[key].filter((x) => x !== value) : [...prev[key], value],
      };
    });
  }

  const catItems = categories.map((c) => ({ value: c.slug, label: getLocalizedValue(c.name, lang) }));
  const brandItems = brands.map((b) => ({ value: b, label: b }));
  const sellerItems = sellers.map((s) => ({ value: s.id, label: s.name }));

  return (
    <div>
      <CheckboxGroup title={t("catalog")} items={catItems} selected={state.cat} onToggle={(v) => toggleIn("cat", v)} />
      <CheckboxGroup title={t("brand")} items={brandItems} selected={state.brand} onToggle={(v) => toggleIn("brand", v)} />

      <div className="filter-group">
        <h4>{t("price")}</h4>
        <div className="price-range">
          <input
            type="number"
            placeholder="от"
            value={state.minPrice ?? ""}
            onChange={(e) => setState((prev) => ({ ...prev, minPrice: e.target.value ? Number(e.target.value) : null }))}
          />
          <span>—</span>
          <input
            type="number"
            placeholder="до"
            value={state.maxPrice ?? ""}
            onChange={(e) => setState((prev) => ({ ...prev, maxPrice: e.target.value ? Number(e.target.value) : null }))}
          />
        </div>
      </div>

      <div className="filter-group">
        <h4>{t("rating")}</h4>
        {ratingOptions.map((r) => (
          <label className="filter-check" key={r}>
            <input
              type="radio"
              name="rating"
              checked={state.minRating === r}
              onChange={() => setState((prev) => ({ ...prev, minRating: r }))}
            />
            <span>★ {r}+</span>
          </label>
        ))}
      </div>

      <CheckboxGroup title={t("seller")} items={sellerItems} selected={state.seller} onToggle={(v) => toggleIn("seller", v)} />
    </div>
  );
}

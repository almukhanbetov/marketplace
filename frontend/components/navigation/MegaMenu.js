"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useLanguage } from "@/context/LanguageContext";
import { categories } from "@/data/categories";

const PROMO_LABELS = {
  ru: [
    ["Скидки недели", "До −40% на технику"],
    ["Новинки сезона", "Только что в каталоге"],
  ],
  kk: [
    ["Апта жеңілдіктері", "Техникаға −40%-ға дейін"],
    ["Маусым жаңалықтары", "Каталогта жаңа ғана"],
  ],
  en: [
    ["Deals of the week", "Up to −40% on tech"],
    ["New this season", "Just added to catalog"],
  ],
};

export default function MegaMenu() {
  const { t, lang } = useLanguage();
  const [open, setOpen] = useState(false);
  const [activeCat, setActiveCat] = useState(categories[0].id);
  const wrapRef = useRef(null);

  useEffect(() => {
    if (!open) return;
    function onClick(e) {
      if (wrapRef.current && !wrapRef.current.contains(e.target)) setOpen(false);
    }
    function onKeyDown(e) {
      if (e.key === "Escape") setOpen(false);
    }
    document.addEventListener("click", onClick);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("click", onClick);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [open]);

  const promos = PROMO_LABELS[lang];
  const activeCategory = categories.find((c) => c.id === activeCat) || categories[0];

  return (
    <div className="catalog-menu-wrap" ref={wrapRef}>
      <button
        className="catalog-trigger"
        aria-expanded={open}
        aria-haspopup="true"
        onClick={(e) => {
          e.stopPropagation();
          setOpen((v) => !v);
        }}
      >
        <span className="icon-burger">
          <span></span>
          <span></span>
          <span></span>
        </span>
        <span className="label-text">{t("catalog")}</span>
      </button>

      <div className={`megamenu ${open ? "open" : ""}`}>
        <div className="megamenu-cats">
          {categories.map((c) => (
            <button
              key={c.id}
              className={`megamenu-cat ${c.id === activeCat ? "active" : ""}`}
              onMouseEnter={() => setActiveCat(c.id)}
              onClick={() => setActiveCat(c.id)}
            >
              <span className="mc-icon">{c.icon}</span>
              <span>{c.label[lang]}</span>
              <span className="mc-arrow">›</span>
            </button>
          ))}
        </div>
        <div className="megamenu-body-wrap" style={{ flex: 1 }}>
          <div className="megamenu-body active">
            <div className="megamenu-grid">
              {activeCategory.sub.map((s, si) => (
                <div className="megamenu-group" key={si}>
                  <h4>{s[lang]}</h4>
                  <ul>
                    <li>
                      <Link href={`/catalog?cat=${activeCategory.id}`} onClick={() => setOpen(false)}>
                        {lang === "en" ? "All in " + s[lang] : s[lang] + " — все товары"}
                      </Link>
                    </li>
                    <li>
                      <Link href={`/catalog?cat=${activeCategory.id}&sort=new`} onClick={() => setOpen(false)}>
                        {t("newArrivals")}
                      </Link>
                    </li>
                    <li>
                      <Link href={`/catalog?cat=${activeCategory.id}&sort=discount`} onClick={() => setOpen(false)}>
                        {t("onSaleNow")}
                      </Link>
                    </li>
                  </ul>
                </div>
              ))}
            </div>
            <div className="megamenu-promo">
              <Link
                href={`/catalog?cat=${activeCategory.id}&sort=discount`}
                className="megamenu-promo-card"
                onClick={() => setOpen(false)}
              >
                <b>{promos[0][0]}</b>
                <span>{promos[0][1]}</span>
              </Link>
              <Link
                href={`/catalog?cat=${activeCategory.id}&sort=new`}
                className="megamenu-promo-card"
                onClick={() => setOpen(false)}
              >
                <b>{promos[1][0]}</b>
                <span>{promos[1][1]}</span>
              </Link>
            </div>
          </div>
        </div>
      </div>
      <div className={`megamenu-backdrop ${open ? "open" : ""}`} onClick={() => setOpen(false)} />
    </div>
  );
}

"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useLanguage } from "@/context/LanguageContext";
import { getProducts } from "@/lib/api/products";
import { adaptProductCard } from "@/lib/api/adapters";
import { formatPrice } from "@/lib/currency";
import { getStorage, setStorage, removeStorage } from "@/lib/storage";

const RECENT_KEY = "mp_recent_searches";
const POPULAR_QUERIES = ["iPhone 17", "Наушники", "Робот-пылесос", "Кроссовки Nike", "MacBook"];

export default function SearchBar() {
  const { t, lang } = useLanguage();
  const router = useRouter();
  const wrapRef = useRef(null);
  const inputRef = useRef(null);

  const [value, setValue] = useState("");
  const [panelOpen, setPanelOpen] = useState(false);
  const [recent, setRecent] = useState([]);
  const [results, setResults] = useState([]);

  useEffect(() => {
    setRecent(getStorage(RECENT_KEY, []));
  }, []);

  useEffect(() => {
    if (!panelOpen) return;
    function onClick(e) {
      if (wrapRef.current && !wrapRef.current.contains(e.target)) setPanelOpen(false);
    }
    function onKeyDown(e) {
      if (e.key === "Escape") setPanelOpen(false);
    }
    document.addEventListener("click", onClick);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("click", onClick);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [panelOpen]);

  // Debounced live-search suggestions from the backend (search= param).
  useEffect(() => {
    const q = value.trim();
    if (!q) {
      setResults([]);
      return;
    }
    let cancelled = false;
    const timer = setTimeout(() => {
      getProducts({ search: q, limit: 6 })
        .then(({ items }) => {
          if (!cancelled) setResults(items.map((p) => adaptProductCard(p, lang)));
        })
        .catch(() => {
          if (!cancelled) setResults([]);
        });
    }, 250);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [value, lang]);

  function addRecent(q) {
    if (!q.trim()) return;
    let list = getStorage(RECENT_KEY, []).filter((x) => x.toLowerCase() !== q.toLowerCase());
    list.unshift(q);
    list = list.slice(0, 6);
    setStorage(RECENT_KEY, list);
    setRecent(list);
  }

  function clearRecent() {
    removeStorage(RECENT_KEY);
    setRecent([]);
  }

  function fillSearch(q) {
    setValue(q);
    inputRef.current?.focus();
  }

  function submit(e) {
    e.preventDefault();
    if (value.trim()) {
      addRecent(value.trim());
      setPanelOpen(false);
      router.push("/catalog?q=" + encodeURIComponent(value.trim()));
    }
  }

  return (
    <div className="search-wrap" ref={wrapRef}>
      <form className={`search-bar ${value.trim() ? "has-value" : ""}`} role="search" onSubmit={submit}>
        <label className="search-cat">
          <span>{t("allCategories")}</span> ▾
        </label>
        <input
          ref={inputRef}
          type="search"
          placeholder={t("searchPlaceholder")}
          autoComplete="off"
          aria-label="Поиск"
          value={value}
          onChange={(e) => setValue(e.target.value)}
          onFocus={() => setPanelOpen(true)}
        />
        <button
          type="button"
          className="search-clear"
          aria-label="Очистить поиск"
          onClick={() => {
            setValue("");
            inputRef.current?.focus();
          }}
        >
          ✕
        </button>
        <button type="submit" className="search-submit" aria-label="Искать">
          🔍
        </button>
      </form>

      <div className={`search-panel ${panelOpen ? "open" : ""}`}>
        {value.trim() ? (
          results.length ? (
            <div className="search-panel-section">
              {results.map((p) => (
                <Link
                  key={p.id}
                  href={`/product/${p.id}`}
                  className="search-suggest-item"
                  onClick={() => setPanelOpen(false)}
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img className="si-thumb" src={p.image} alt="" />
                  <span>{p.title}</span>
                  <span className="si-price">{formatPrice(p.price)}</span>
                </Link>
              ))}
            </div>
          ) : (
            <div className="search-panel-section">
              <p className="text-muted" style={{ padding: 10 }}>
                Ничего не найдено
              </p>
            </div>
          )
        ) : (
          <>
            {recent.length > 0 && (
              <div className="search-panel-section">
                <div className="eyebrow">
                  <span>{t("recentSearches")}</span>
                  <button onClick={clearRecent}>{t("clear")}</button>
                </div>
                <div className="search-chip-row">
                  {recent.map((r) => (
                    <button key={r} className="search-chip" onClick={() => fillSearch(r)}>
                      {r}
                    </button>
                  ))}
                </div>
              </div>
            )}
            <div className="search-panel-section">
              <div className="eyebrow">
                <span>{t("popularSearches")}</span>
              </div>
              <div className="search-chip-row">
                {POPULAR_QUERIES.map((r) => (
                  <button key={r} className="search-chip" onClick={() => fillSearch(r)}>
                    {r}
                  </button>
                ))}
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useLanguage } from "@/context/LanguageContext";
import { getProducts } from "@/lib/api/products";
import { getCategories } from "@/lib/api/categories";
import { getSellers } from "@/lib/api/sellers";
import { adaptProductCard, getLocalizedValue } from "@/lib/api/adapters";
import FiltersPanel from "@/components/filters/FiltersPanel";
import ProductGrid from "@/components/product/ProductGrid";
import Drawer from "@/components/ui/Drawer";

const PAGE_SIZE = 24;

// Whitelisted UI sort value -> backend sort value. The <select> keeps its
// existing options/labels unchanged; only this mapping is new. "popular"
// has no direct backend equivalent (no review-count sort in the Stage 3
// whitelist), so it's approximated with rating_desc.
const SORT_MAP = {
  popular: "rating_desc",
  cheap: "price_asc",
  expensive: "price_desc",
  rating: "rating_desc",
  new: "newest",
  discount: "discount_desc",
};

const INITIAL_STATE = {
  cat: [], brand: [], seller: [],
  minRating: 0, minPrice: null, maxPrice: null,
  sort: "popular", q: "",
};

export default function CatalogPage() {
  const { t, lang } = useLanguage();
  const router = useRouter();
  const searchParams = useSearchParams();
  const [state, setState] = useState(INITIAL_STATE);
  const [page, setPage] = useState(1);
  const [mobileFiltersOpen, setMobileFiltersOpen] = useState(false);
  const [initialized, setInitialized] = useState(false);

  const [products, setProducts] = useState([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(false);

  const [facetCategories, setFacetCategories] = useState([]);
  const [facetSellers, setFacetSellers] = useState([]);
  const [facetBrands, setFacetBrands] = useState([]);

  // Filter/sort/search changes always jump back to page 1; explicit page
  // navigation (goToPage) is the only thing that changes page without also
  // resetting the filters.
  const setFilterState = useCallback((updater) => {
    setState(updater);
    setPage(1);
  }, []);

  // Hydrate filter/sort/page state from the URL once on mount, so the
  // catalog is shareable and survives a refresh/back-navigation.
  useEffect(() => {
    const cat = searchParams.get("cat");
    const brand = searchParams.get("brand");
    const seller = searchParams.get("seller");
    const sort = searchParams.get("sort");
    const q = searchParams.get("q");
    const rating = searchParams.get("rating");
    const minPrice = searchParams.get("min_price");
    const maxPrice = searchParams.get("max_price");
    const pageParam = searchParams.get("page");
    setState({
      cat: cat ? [cat] : [],
      brand: brand ? [brand] : [],
      seller: seller ? [Number(seller)] : [],
      minRating: rating ? Number(rating) : 0,
      minPrice: minPrice ? Number(minPrice) : null,
      maxPrice: maxPrice ? Number(maxPrice) : null,
      sort: sort && SORT_MAP[sort] ? sort : "popular",
      q: q || "",
    });
    setPage(pageParam ? Math.max(1, Number(pageParam)) : 1);
    setInitialized(true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Facet data (category/seller/brand lists for the filter panel) — fetched
  // once and independent of the current product filters.
  useEffect(() => {
    let cancelled = false;
    Promise.all([getCategories(), getSellers(), getProducts({ limit: 100 })])
      .then(([cats, sellerList, facetProductsRes]) => {
        if (cancelled) return;
        setFacetCategories(cats);
        setFacetSellers(sellerList);
        setFacetBrands([...new Set(facetProductsRes.items.map((p) => p.brand))].sort());
      })
      .catch(() => {
        // Facet lists are a filter-panel convenience — losing them isn't
        // fatal, the product list itself still loads.
      });
    return () => {
      cancelled = true;
    };
  }, []);

  // Reflect filter/sort/search/page state into the URL and fetch matching
  // products from the backend.
  useEffect(() => {
    if (!initialized) return;

    const params = new URLSearchParams();
    if (state.cat[0]) params.set("cat", state.cat[0]);
    if (state.brand[0]) params.set("brand", state.brand[0]);
    if (state.seller[0]) params.set("seller", String(state.seller[0]));
    if (state.minRating) params.set("rating", String(state.minRating));
    if (state.minPrice) params.set("min_price", String(state.minPrice));
    if (state.maxPrice) params.set("max_price", String(state.maxPrice));
    if (state.sort && state.sort !== "popular") params.set("sort", state.sort);
    if (state.q) params.set("q", state.q);
    if (page > 1) params.set("page", String(page));
    const qs = params.toString();
    router.replace(`/catalog${qs ? "?" + qs : ""}`, { scroll: false });

    let cancelled = false;
    setLoading(true);
    setLoadError(false);
    getProducts({
      search: state.q || undefined,
      category: state.cat[0] || undefined,
      brand: state.brand[0] || undefined,
      seller: state.seller[0] || undefined,
      min_price: state.minPrice || undefined,
      max_price: state.maxPrice || undefined,
      rating: state.minRating || undefined,
      sort: SORT_MAP[state.sort],
      limit: PAGE_SIZE,
      offset: (page - 1) * PAGE_SIZE,
    })
      .then(({ items, meta }) => {
        if (cancelled) return;
        setProducts(items.map((p) => adaptProductCard(p, lang)));
        setTotal(meta.total);
      })
      .catch(() => {
        if (cancelled) return;
        setProducts([]);
        setTotal(0);
        setLoadError(true);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state, page, initialized, lang]);

  const activeFilters = useMemo(() => {
    const chips = [];
    state.cat.forEach((c) => {
      const cat = facetCategories.find((x) => x.slug === c);
      const label = cat ? getLocalizedValue(cat.name, lang) : c;
      chips.push({ label, clear: () => setFilterState((p) => ({ ...p, cat: [] })) });
    });
    state.brand.forEach((b) => chips.push({ label: b, clear: () => setFilterState((p) => ({ ...p, brand: [] })) }));
    state.seller.forEach((s) => {
      const seller = facetSellers.find((x) => x.id === s);
      chips.push({ label: seller ? seller.name : String(s), clear: () => setFilterState((p) => ({ ...p, seller: [] })) });
    });
    if (state.minRating) {
      chips.push({ label: "★ " + state.minRating + "+", clear: () => setFilterState((p) => ({ ...p, minRating: 0 })) });
    }
    return chips;
  }, [state, lang, facetCategories, facetSellers, setFilterState]);

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  if (!initialized) return null;

  return (
    <>
      <div className="container page-section--tight">
        <nav className="breadcrumbs" aria-label="Breadcrumb">
          <Link href="/">{t("home")}</Link>
          <span aria-hidden="true">/</span>
          <span>{t("catalog")}</span>
        </nav>
      </div>

      <div className="container page-section--tight">
        <div className="layout-with-sidebar">
          <aside className="sidebar-card desktop-only" aria-label="Фильтры">
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 6 }}>
              <h3 style={{ fontSize: "var(--fs-md)", fontWeight: 800 }}>{t("filters")}</h3>
              <button className="btn btn--ghost btn--sm" onClick={() => setFilterState(INITIAL_STATE)}>
                Сбросить
              </button>
            </div>
            <FiltersPanel state={state} setState={setFilterState} categories={facetCategories} sellers={facetSellers} brands={facetBrands} />
          </aside>

          <div>
            <div className="active-filters">
              {activeFilters.map((c, i) => (
                <span className="active-filter-chip" key={i}>
                  {c.label}
                  <button onClick={c.clear}>✕</button>
                </span>
              ))}
            </div>
            <div className="toolbar">
              <div className="result-count">
                <b>{total}</b> {t("resultsFound")}
              </div>
              <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
                <button className="btn btn--outline btn--sm tablet-only" onClick={() => setMobileFiltersOpen(true)}>
                  ⚙ {t("filters")}
                </button>
                <div className="sort-select">
                  <span>{t("sortBy")}</span>:
                  <select value={state.sort} onChange={(e) => setFilterState((p) => ({ ...p, sort: e.target.value }))}>
                    <option value="popular">{t("sortPopular")}</option>
                    <option value="cheap">{t("sortCheap")}</option>
                    <option value="expensive">{t("sortExpensive")}</option>
                    <option value="rating">{t("sortRating")}</option>
                    <option value="new">{t("sortNew")}</option>
                    <option value="discount">{t("sortDiscount")}</option>
                  </select>
                </div>
              </div>
            </div>

            {loadError ? (
              <div className="empty-state">
                <div className="empty-state__icon">⚠</div>
                <h3>{lang === "en" ? "Couldn't load products" : "Не удалось загрузить товары"}</h3>
                <p>{lang === "en" ? "Please check your connection and try again." : "Проверьте соединение и попробуйте снова."}</p>
              </div>
            ) : loading ? (
              <div className="empty-state">
                <div className="empty-state__icon">⏳</div>
                <h3>{lang === "en" ? "Loading…" : "Загрузка…"}</h3>
              </div>
            ) : (
              <>
                <ProductGrid products={products} />
                {totalPages > 1 && (
                  <div style={{ display: "flex", justifyContent: "center", gap: 8, marginTop: 24 }}>
                    <button
                      className="btn btn--outline btn--sm"
                      disabled={page <= 1}
                      onClick={() => setPage((p) => Math.max(1, p - 1))}
                    >
                      ‹
                    </button>
                    <span style={{ display: "flex", alignItems: "center", padding: "0 10px" }}>
                      {page} / {totalPages}
                    </span>
                    <button
                      className="btn btn--outline btn--sm"
                      disabled={page >= totalPages}
                      onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                    >
                      ›
                    </button>
                  </div>
                )}
              </>
            )}
          </div>
        </div>
      </div>

      <Drawer
        open={mobileFiltersOpen}
        onClose={() => setMobileFiltersOpen(false)}
        title={t("filters")}
        ariaLabel="Фильтры"
        footer={
          <button className="btn btn--primary btn--block btn--lg" onClick={() => setMobileFiltersOpen(false)}>
            Показать результаты
          </button>
        }
      >
        <div style={{ padding: "14px 0" }}>
          <FiltersPanel state={state} setState={setFilterState} categories={facetCategories} sellers={facetSellers} brands={facetBrands} />
        </div>
      </Drawer>
    </>
  );
}

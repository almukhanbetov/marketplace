"use client";

import { createContext, useContext, useEffect, useState, useCallback, useMemo } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { getFavorites, addFavorite, removeFavorite } from "@/lib/api/favorites";
import { adaptProductCard } from "@/lib/api/adapters";
import { useAuth } from "@/context/AuthContext";
import { useModal } from "@/context/ModalContext";

const FavoritesContext = createContext(null);

/**
 * Backend-backed favorites (Stage 5) — the demo user's DB row is the sole
 * source of truth; nothing here is persisted to localStorage. `ids` is
 * kept for the many call sites that only need a fast membership check;
 * `optimisticIds`, when set, overrides it for instant heart-icon feedback
 * ahead of the network round trip, and is rolled back on failure (§28).
 */
export function FavoritesProvider({ children }) {
  const { lang } = useLanguage();
  const { mounted, isAuthenticated } = useAuth();
  const { openModal } = useModal();
  const [rawItems, setRawItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [optimisticIds, setOptimisticIds] = useState(null);

  // Stage 9 §49: no anonymous DB favorites are ever created — a
  // logged-out visitor simply sees an empty favorites list.
  const refresh = useCallback(async () => {
    if (!isAuthenticated) {
      setRawItems([]);
      return;
    }
    try {
      const data = await getFavorites();
      setRawItems(data);
    } catch {
      setRawItems([]);
    }
  }, [isAuthenticated]);

  useEffect(() => {
    if (!mounted) return;
    refresh().finally(() => setLoading(false));
  }, [mounted, isAuthenticated, refresh]);

  const items = useMemo(() => rawItems.map((p) => adaptProductCard(p, lang)), [rawItems, lang]);
  const serverIds = useMemo(() => items.map((p) => p.id), [items]);
  const ids = optimisticIds ?? serverIds;

  const isFavorite = useCallback((id) => ids.includes(id), [ids]);

  const addFavoriteFn = useCallback(
    async (product) => {
      if (!isAuthenticated) {
        openModal("login");
        throw new Error("loginRequired");
      }
      setOptimisticIds((prev) => {
        const base = prev ?? serverIds;
        return base.includes(product.id) ? base : [...base, product.id];
      });
      try {
        await addFavorite(product.id);
        await refresh();
      } catch (err) {
        setOptimisticIds(null); // rollback to server truth
        throw err;
      } finally {
        setOptimisticIds(null);
      }
    },
    [serverIds, refresh, isAuthenticated, openModal]
  );

  const removeFavoriteFn = useCallback(
    async (id) => {
      setOptimisticIds((prev) => (prev ?? serverIds).filter((x) => x !== id));
      try {
        await removeFavorite(id);
        await refresh();
      } catch (err) {
        setOptimisticIds(null);
        throw err;
      } finally {
        setOptimisticIds(null);
      }
    },
    [serverIds, refresh]
  );

  /** Returns true if the item became a favorite, false if it was removed —
   * matching the pre-Stage-5 signature so existing toast logic keeps
   * working, just async now. */
  const toggleFavorite = useCallback(
    async (product) => {
      if (ids.includes(product.id)) {
        await removeFavoriteFn(product.id);
        return false;
      }
      await addFavoriteFn(product);
      return true;
    },
    [ids, addFavoriteFn, removeFavoriteFn]
  );

  const value = useMemo(
    () => ({
      items,
      ids,
      count: ids.length,
      loading,
      isFavorite,
      addFavorite: addFavoriteFn,
      removeFavorite: removeFavoriteFn,
      toggleFavorite,
      refresh,
    }),
    [items, ids, loading, isFavorite, addFavoriteFn, removeFavoriteFn, toggleFavorite, refresh]
  );

  return <FavoritesContext.Provider value={value}>{children}</FavoritesContext.Provider>;
}

export function useFavorites() {
  const ctx = useContext(FavoritesContext);
  if (!ctx) throw new Error("useFavorites must be used within FavoritesProvider");
  return ctx;
}

"use client";

import { createContext, useContext, useEffect, useState, useCallback, useMemo } from "react";
import { getStorage, setStorage } from "@/lib/storage";

const COMPARE_KEY = "mp_compare";
const MAX_COMPARE = 4;
const CompareContext = createContext(null);

export function CompareProvider({ children }) {
  const [ids, setIds] = useState([]);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setIds(getStorage(COMPARE_KEY, []));
    setMounted(true);
  }, []);

  useEffect(() => {
    if (!mounted) return;
    setStorage(COMPARE_KEY, ids);
  }, [ids, mounted]);

  const isCompared = useCallback((id) => ids.includes(id), [ids]);

  const addToCompare = useCallback((id) => {
    setIds((prev) => (prev.includes(id) || prev.length >= MAX_COMPARE ? prev : [...prev, id]));
  }, []);

  const removeFromCompare = useCallback((id) => {
    setIds((prev) => prev.filter((x) => x !== id));
  }, []);

  /** Returns "added" | "removed" | "full" so callers can toast appropriately. */
  const toggleCompare = useCallback((id) => {
    let result = "added";
    setIds((prev) => {
      if (prev.includes(id)) {
        result = "removed";
        return prev.filter((x) => x !== id);
      }
      if (prev.length >= MAX_COMPARE) {
        result = "full";
        return prev;
      }
      result = "added";
      return [...prev, id];
    });
    return result;
  }, []);

  const value = useMemo(
    () => ({ ids, count: ids.length, max: MAX_COMPARE, isCompared, addToCompare, removeFromCompare, toggleCompare }),
    [ids, isCompared, addToCompare, removeFromCompare, toggleCompare]
  );

  return <CompareContext.Provider value={value}>{children}</CompareContext.Provider>;
}

export function useCompare() {
  const ctx = useContext(CompareContext);
  if (!ctx) throw new Error("useCompare must be used within CompareProvider");
  return ctx;
}

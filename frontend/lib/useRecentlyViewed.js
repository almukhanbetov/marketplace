"use client";

import { useCallback, useEffect, useState } from "react";
import { getStorage, setStorage } from "@/lib/storage";
import { useProductsByIds } from "@/lib/useProductsByIds";

const KEY = "mp_recent";
const MAX = 10;

export function addRecentlyViewed(id) {
  let list = getStorage(KEY, []);
  list = list.filter((x) => x !== id);
  list.unshift(id);
  list = list.slice(0, MAX);
  setStorage(KEY, list);
}

/** Returns the recently-viewed products list, refreshed on mount. The id
 * list itself still lives in localStorage (Stage 5 §40 only requires
 * favorites/cart/addresses to drop it) — only the product data behind each
 * id now comes from the real API instead of the mock catalog. */
export function useRecentlyViewed() {
  const [ids, setIds] = useState([]);

  useEffect(() => {
    setIds(getStorage(KEY, []));
  }, []);

  const refresh = useCallback(() => setIds(getStorage(KEY, [])), []);

  const items = useProductsByIds(ids);

  return { items, refresh };
}

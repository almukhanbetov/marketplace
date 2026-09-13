"use client";

import { createContext, useContext, useEffect, useState, useCallback } from "react";
import { getRawStorage, setRawStorage } from "@/lib/storage";

const THEME_KEY = "mp_theme";
const ThemeContext = createContext(null);

/**
 * Server-render always assumes "dark" (matches the blocking inline script's
 * fallback in app/layout.js) so hydration never mismatches. The real saved
 * theme is applied in an effect right after mount.
 */
export function ThemeProvider({ children }) {
  const [theme, setTheme] = useState("dark");
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    const saved = getRawStorage(THEME_KEY, "dark");
    setTheme(saved === "vivid" ? "vivid" : "dark");
    setMounted(true);
  }, []);

  useEffect(() => {
    if (!mounted) return;
    if (theme === "vivid") {
      document.documentElement.setAttribute("data-theme", "vivid");
    } else {
      document.documentElement.removeAttribute("data-theme");
    }
    setRawStorage(THEME_KEY, theme);
  }, [theme, mounted]);

  const toggle = useCallback(() => {
    setTheme((prev) => (prev === "vivid" ? "dark" : "vivid"));
  }, []);

  const apply = useCallback((next) => {
    setTheme(next === "vivid" ? "vivid" : "dark");
  }, []);

  return (
    <ThemeContext.Provider value={{ theme, toggle, apply }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error("useTheme must be used within ThemeProvider");
  return ctx;
}

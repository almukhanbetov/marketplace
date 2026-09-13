"use client";

import { createContext, useContext, useEffect, useState, useCallback, useMemo } from "react";
import { getRawStorage, setRawStorage } from "@/lib/storage";
import { translations } from "@/data/translations";

const LANG_KEY = "mp_lang";
const LanguageContext = createContext(null);

export function LanguageProvider({ children }) {
  const [lang, setLangState] = useState("ru");

  useEffect(() => {
    setLangState(getRawStorage(LANG_KEY, "ru"));
  }, []);

  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);

  const setLang = useCallback((next) => {
    setLangState(next);
    setRawStorage(LANG_KEY, next);
  }, []);

  const t = useCallback(
    (key) => (translations[lang] && translations[lang][key]) || translations.ru[key] || key,
    [lang]
  );

  const value = useMemo(() => ({ lang, setLang, t }), [lang, setLang, t]);

  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
}

export function useLanguage() {
  const ctx = useContext(LanguageContext);
  if (!ctx) throw new Error("useLanguage must be used within LanguageProvider");
  return ctx;
}

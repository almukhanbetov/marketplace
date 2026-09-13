"use client";

import { useLanguage } from "@/context/LanguageContext";

export default function LanguageSwitcher() {
  const { lang, setLang } = useLanguage();

  return (
    <div className="lang-switch">
      <button className={lang === "kk" ? "active" : ""} onClick={() => setLang("kk")}>
        KAZ
      </button>
      <button className={lang === "ru" ? "active" : ""} onClick={() => setLang("ru")}>
        RU
      </button>
      <button className={lang === "en" ? "active" : ""} onClick={() => setLang("en")}>
        ENG
      </button>
    </div>
  );
}

/* ==========================================================================
   LANGUAGE SWITCHING (ru / kk / en) — persisted via localStorage
   ========================================================================== */

const LanguageManager = {
  KEY: "mp_lang",

  init() {
    if (!localStorage.getItem(this.KEY)) {
      localStorage.setItem(this.KEY, "ru");
    }
    this.applyTranslations();
    this.syncButtons();
    document.querySelectorAll("[data-lang-btn]").forEach((btn) => {
      btn.addEventListener("click", () => this.set(btn.getAttribute("data-lang-btn")));
    });
  },

  get() {
    return localStorage.getItem(this.KEY) || "ru";
  },

  set(lang) {
    localStorage.setItem(this.KEY, lang);
    this.applyTranslations();
    this.syncButtons();
    document.dispatchEvent(new CustomEvent("langchange", { detail: { lang } }));
  },

  syncButtons() {
    const lang = this.get();
    document.querySelectorAll("[data-lang-btn]").forEach((btn) => {
      btn.classList.toggle("active", btn.getAttribute("data-lang-btn") === lang);
    });
  },

  applyTranslations() {
    document.querySelectorAll("[data-i18n]").forEach((el) => {
      el.textContent = t(el.getAttribute("data-i18n"));
    });
    document.querySelectorAll("[data-i18n-placeholder]").forEach((el) => {
      el.setAttribute("placeholder", t(el.getAttribute("data-i18n-placeholder")));
    });
    document.querySelectorAll("[data-i18n-aria]").forEach((el) => {
      el.setAttribute("aria-label", t(el.getAttribute("data-i18n-aria")));
    });
    document.documentElement.lang = this.get();
  },
};

document.addEventListener("DOMContentLoaded", () => LanguageManager.init());

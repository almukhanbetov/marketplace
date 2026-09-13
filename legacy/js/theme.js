/* ==========================================================================
   THEME SWITCHING (dark / vivid) — persisted via localStorage
   ========================================================================== */

const ThemeManager = {
  KEY: "mp_theme",

  init() {
    const saved = localStorage.getItem(this.KEY) || "dark";
    this.apply(saved, false);
    document.querySelectorAll("[data-theme-toggle]").forEach((btn) => {
      btn.addEventListener("click", () => this.toggle());
    });
  },

  apply(theme, animate = true) {
    if (theme === "vivid") {
      document.documentElement.setAttribute("data-theme", "vivid");
    } else {
      document.documentElement.removeAttribute("data-theme");
      theme = "dark";
    }
    localStorage.setItem(this.KEY, theme);
    document.querySelectorAll("[data-theme-toggle]").forEach((btn) => {
      btn.textContent = theme === "vivid" ? "🌙" : "☀️";
      btn.setAttribute("aria-label", theme === "vivid" ? "Switch to dark theme" : "Switch to vivid theme");
    });
  },

  toggle() {
    const current = localStorage.getItem(this.KEY) || "dark";
    this.apply(current === "vivid" ? "dark" : "vivid");
  },
};

document.addEventListener("DOMContentLoaded", () => ThemeManager.init());

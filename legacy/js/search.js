/* ==========================================================================
   SEARCH — suggestions, recent & popular searches
   ========================================================================== */

const popularQueries = ["iPhone 17", "Наушники", "Робот-пылесос", "Кроссовки Nike", "MacBook"];

const Search = {
  RECENT_KEY: "mp_recent_searches",

  getRecent() {
    return JSON.parse(localStorage.getItem(this.RECENT_KEY) || "[]");
  },

  addRecent(q) {
    if (!q.trim()) return;
    let list = this.getRecent().filter((x) => x.toLowerCase() !== q.toLowerCase());
    list.unshift(q);
    list = list.slice(0, 6);
    localStorage.setItem(this.RECENT_KEY, JSON.stringify(list));
  },

  clearRecent() {
    localStorage.removeItem(this.RECENT_KEY);
  },

  query(text) {
    const q = text.trim().toLowerCase();
    if (!q) return [];
    return products
      .filter((p) => p.title.toLowerCase().includes(q) || p.brand.toLowerCase().includes(q) || p.category.includes(q))
      .slice(0, 6);
  },

  init() {
    const wrap = document.querySelector("[data-search-wrap]");
    if (!wrap) return;
    const input = wrap.querySelector("input");
    const panel = wrap.querySelector("[data-search-panel]");
    const bar = wrap.querySelector(".search-bar");
    const clearBtn = wrap.querySelector(".search-clear");
    const form = wrap.querySelector("form");

    const renderDefault = () => {
      const recent = this.getRecent();
      panel.innerHTML = `
        ${
          recent.length
            ? `<div class="search-panel-section">
          <div class="eyebrow"><span>${t("recentSearches")}</span><button data-clear-recent>${t("clear")}</button></div>
          <div class="search-chip-row">${recent.map((r) => `<button class="search-chip" data-fill-search="${r}">${r}</button>`).join("")}</div>
        </div>`
            : ""
        }
        <div class="search-panel-section">
          <div class="eyebrow"><span>${t("popularSearches")}</span></div>
          <div class="search-chip-row">${popularQueries.map((r) => `<button class="search-chip" data-fill-search="${r}">${r}</button>`).join("")}</div>
        </div>`;
      panel.querySelectorAll("[data-fill-search]").forEach((btn) =>
        btn.addEventListener("click", () => {
          input.value = btn.getAttribute("data-fill-search");
          input.dispatchEvent(new Event("input"));
          input.focus();
        })
      );
      panel.querySelector("[data-clear-recent]")?.addEventListener("click", () => {
        this.clearRecent();
        renderDefault();
      });
    };

    const renderResults = (q) => {
      const results = this.query(q);
      if (!results.length) {
        panel.innerHTML = `<div class="search-panel-section"><p class="text-muted" style="padding:10px">Ничего не найдено</p></div>`;
        return;
      }
      panel.innerHTML = `<div class="search-panel-section">
        ${results
          .map(
            (p) => `
          <a href="product.html?id=${p.id}" class="search-suggest-item">
            <img class="si-thumb" src="${p.image}" alt="">
            <span>${p.title}</span>
            <span class="si-price">${formatPrice(p.price)}</span>
          </a>`
          )
          .join("")}
      </div>`;
    };

    input.addEventListener("focus", () => {
      panel.classList.add("open");
      if (!input.value.trim()) renderDefault();
    });

    input.addEventListener("input", () => {
      bar.classList.toggle("has-value", !!input.value.trim());
      if (input.value.trim()) {
        renderResults(input.value);
      } else {
        renderDefault();
      }
      panel.classList.add("open");
    });

    clearBtn?.addEventListener("click", () => {
      input.value = "";
      bar.classList.remove("has-value");
      renderDefault();
      input.focus();
    });

    form?.addEventListener("submit", (e) => {
      e.preventDefault();
      if (input.value.trim()) {
        this.addRecent(input.value.trim());
        window.location.href = "catalog.html?q=" + encodeURIComponent(input.value.trim());
      }
    });

    document.addEventListener("click", (e) => {
      if (!wrap.contains(e.target)) panel.classList.remove("open");
    });
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") panel.classList.remove("open");
    });

    document.addEventListener("langchange", () => {
      if (!input.value.trim()) renderDefault();
    });
  },
};

document.addEventListener("DOMContentLoaded", () => Search.init());

/* ==========================================================================
   APP — global wiring: header, mega menu, dropdowns, hero slider, flash sale
   ========================================================================== */

/* ---- Sticky header shadow ---- */
(function headerShadow() {
  const header = document.querySelector(".site-header");
  if (!header) return;
  const onScroll = () => header.classList.toggle("scrolled", window.scrollY > 4);
  document.addEventListener("scroll", onScroll, { passive: true });
  onScroll();
})();

/* ---- Mega menu ---- */
function buildMegaMenu() {
  const menu = document.querySelector("[data-megamenu]");
  if (!menu || typeof categories === "undefined") return;
  const lang = LanguageManager.get();
  const promoLabels = {
    ru: [["Скидки недели", "До −40% на технику"], ["Новинки сезона", "Только что в каталоге"]],
    kk: [["Апта жеңілдіктері", "Техникаға −40%-ға дейін"], ["Маусым жаңалықтары", "Каталогта жаңа ғана"]],
    en: [["Deals of the week", "Up to −40% on tech"], ["New this season", "Just added to catalog"]],
  };
  const promos = promoLabels[lang];

  menu.innerHTML = `
    <div class="megamenu-cats">
      ${categories
        .map(
          (c, i) => `
        <button class="megamenu-cat ${i === 0 ? "active" : ""}" data-cat="${c.id}">
          <span class="mc-icon">${c.icon}</span><span>${c.label[lang]}</span><span class="mc-arrow">›</span>
        </button>`
        )
        .join("")}
    </div>
    <div class="megamenu-body-wrap" style="flex:1">
      ${categories
        .map(
          (c, i) => `
        <div class="megamenu-body ${i === 0 ? "active" : ""}" data-cat-body="${c.id}">
          <div class="megamenu-grid">
            ${c.sub
              .map(
                (s, si) => `
              <div class="megamenu-group">
                <h4>${s[lang]}</h4>
                <ul>
                  <li><a href="catalog.html?cat=${c.id}">${lang === "en" ? "All in " + s[lang] : s[lang] + " — все товары"}</a></li>
                  <li><a href="catalog.html?cat=${c.id}&sort=new">${t("newArrivals")}</a></li>
                  <li><a href="catalog.html?cat=${c.id}&sort=discount">${t("onSaleNow")}</a></li>
                </ul>
              </div>`
              )
              .join("")}
          </div>
          <div class="megamenu-promo">
            <a href="catalog.html?cat=${c.id}&sort=discount" class="megamenu-promo-card"><b>${promos[0][0]}</b><span>${promos[0][1]}</span></a>
            <a href="catalog.html?cat=${c.id}&sort=new" class="megamenu-promo-card"><b>${promos[1][0]}</b><span>${promos[1][1]}</span></a>
          </div>
        </div>`
        )
        .join("")}
    </div>`;
}

(function megaMenu() {
  const trigger = document.querySelector("[data-catalog-trigger]");
  const menu = document.querySelector("[data-megamenu]");
  const backdrop = document.querySelector("[data-megamenu-backdrop]");
  if (!trigger || !menu) return;

  buildMegaMenu();
  document.addEventListener("langchange", buildMegaMenu);

  menu.addEventListener("mouseover", (e) => {
    const btn = e.target.closest("[data-cat]");
    if (btn) showCat(btn.getAttribute("data-cat"));
  });
  menu.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-cat]");
    if (btn) showCat(btn.getAttribute("data-cat"));
  });

  function showCat(id) {
    menu.querySelectorAll("[data-cat]").forEach((b) => b.classList.toggle("active", b.getAttribute("data-cat") === id));
    menu.querySelectorAll("[data-cat-body]").forEach((b) => b.classList.toggle("active", b.getAttribute("data-cat-body") === id));
  }

  function open() {
    menu.classList.add("open");
    backdrop?.classList.add("open");
    trigger.setAttribute("aria-expanded", "true");
  }
  function close() {
    menu.classList.remove("open");
    backdrop?.classList.remove("open");
    trigger.setAttribute("aria-expanded", "false");
  }
  trigger.addEventListener("click", (e) => {
    e.stopPropagation();
    menu.classList.contains("open") ? close() : open();
  });
  document.addEventListener("click", (e) => {
    if (!menu.contains(e.target) && e.target !== trigger) close();
  });
  document.addEventListener("keydown", (e) => e.key === "Escape" && close());
  backdrop?.addEventListener("click", close);
})();

/* ---- User dropdown ---- */
(function userDropdown() {
  const trigger = document.querySelector("[data-user-trigger]");
  const panel = document.querySelector("[data-user-panel]");
  if (!trigger || !panel) return;
  trigger.addEventListener("click", (e) => {
    e.stopPropagation();
    panel.classList.toggle("open");
    document.querySelector("[data-notif-panel]")?.classList.remove("open");
  });
  panel.addEventListener("click", (e) => e.stopPropagation());
  document.addEventListener("click", () => panel.classList.remove("open"));
})();

/* ---- Mobile menu (mega menu reused) is handled by same trigger on mobile ---- */

/* ---- Hero slider ---- */
(function heroSlider() {
  const root = document.querySelector("[data-hero-slider]");
  if (!root) return;
  const slides = [...root.querySelectorAll(".hero-slide")];
  const dots = [...root.querySelectorAll("[data-dot]")];
  let index = 0;
  let timer;

  function go(i) {
    index = (i + slides.length) % slides.length;
    slides.forEach((s, n) => s.classList.toggle("active", n === index));
    dots.forEach((d, n) => d.classList.toggle("active", n === index));
  }
  function next() { go(index + 1); }
  function prev() { go(index - 1); }
  function play() { timer = setInterval(next, 5000); }
  function stop() { clearInterval(timer); }

  root.querySelector("[data-hero-next]")?.addEventListener("click", () => { next(); stop(); play(); });
  root.querySelector("[data-hero-prev]")?.addEventListener("click", () => { prev(); stop(); play(); });
  dots.forEach((d, n) => d.addEventListener("click", () => { go(n); stop(); play(); }));
  root.addEventListener("mouseenter", stop);
  root.addEventListener("mouseleave", play);

  let touchX = null;
  root.addEventListener("touchstart", (e) => (touchX = e.touches[0].clientX), { passive: true });
  root.addEventListener("touchend", (e) => {
    if (touchX === null) return;
    const dx = e.changedTouches[0].clientX - touchX;
    if (Math.abs(dx) > 40) (dx < 0 ? next() : prev());
    touchX = null;
  });

  go(0);
  play();
})();

/* ---- Flash sale countdown ---- */
(function flashCountdown() {
  document.querySelectorAll("[data-countdown]").forEach((el) => {
    const KEY = "mp_flash_end";
    let end = Number(localStorage.getItem(KEY));
    if (!end || end < Date.now()) {
      end = Date.now() + (2 * 3600 + 41 * 60 + 17) * 1000;
      localStorage.setItem(KEY, String(end));
    }
    const h = el.querySelector("[data-cd-h]");
    const m = el.querySelector("[data-cd-m]");
    const s = el.querySelector("[data-cd-s]");
    function tick() {
      let diff = Math.max(0, end - Date.now());
      const hh = Math.floor(diff / 3600000);
      const mm = Math.floor((diff % 3600000) / 60000);
      const ss = Math.floor((diff % 60000) / 1000);
      if (h) h.textContent = String(hh).padStart(2, "0");
      if (m) m.textContent = String(mm).padStart(2, "0");
      if (s) s.textContent = String(ss).padStart(2, "0");
      if (diff <= 0) {
        localStorage.removeItem(KEY);
        clearInterval(interval);
      }
    }
    tick();
    const interval = setInterval(tick, 1000);
  });
})();

/* ---- Carousel arrow scroll ---- */
document.querySelectorAll(".carousel-wrap").forEach((wrap) => {
  const track = wrap.querySelector(".carousel-track");
  wrap.querySelector(".carousel-nav--prev")?.addEventListener("click", () => track.scrollBy({ left: -480, behavior: "smooth" }));
  wrap.querySelector(".carousel-nav--next")?.addEventListener("click", () => track.scrollBy({ left: 480, behavior: "smooth" }));
});

/* ---- Fake login state (demo) ---- */
const Auth = {
  KEY: "mp_user",
  get() {
    try { return JSON.parse(localStorage.getItem(this.KEY)); } catch { return null; }
  },
  login(name, email) {
    localStorage.setItem(this.KEY, JSON.stringify({ name, email }));
    document.dispatchEvent(new CustomEvent("authchange"));
  },
  logout() {
    localStorage.removeItem(this.KEY);
    document.dispatchEvent(new CustomEvent("authchange"));
  },
};

function renderAuthUI() {
  const user = Auth.get();
  document.querySelectorAll("[data-auth-guest]").forEach((el) => (el.style.display = user ? "none" : ""));
  document.querySelectorAll("[data-auth-user]").forEach((el) => (el.style.display = user ? "" : "none"));
  document.querySelectorAll("[data-auth-name]").forEach((el) => { if (user) el.textContent = user.name; });
}
document.addEventListener("authchange", renderAuthUI);
document.addEventListener("DOMContentLoaded", () => {
  renderAuthUI();
  const loginForm = document.querySelector("[data-login-form]");
  loginForm?.addEventListener("submit", (e) => {
    e.preventDefault();
    const name = loginForm.querySelector("[name=name]")?.value || "Пользователь";
    const email = loginForm.querySelector("[name=email]")?.value || "";
    Auth.login(name, email);
    ModalManager.close("login-modal");
    Toast.show("Вы вошли как " + name, "success", "✓");
  });
  document.querySelectorAll("[data-logout]").forEach((btn) =>
    btn.addEventListener("click", (e) => {
      e.preventDefault();
      Auth.logout();
      Toast.show("Вы вышли из аккаунта", "info", "👋");
    })
  );
});

/* ---- Mobile nav active state ---- */
document.addEventListener("DOMContentLoaded", () => {
  const path = location.pathname.split("/").pop() || "index.html";
  document.querySelectorAll(".mobile-nav a").forEach((a) => {
    a.classList.toggle("active", a.getAttribute("href") === path);
  });
});

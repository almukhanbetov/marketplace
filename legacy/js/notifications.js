/* ==========================================================================
   TOAST SYSTEM + NOTIFICATION CENTER
   ========================================================================== */

const Toast = {
  stack: null,

  init() {
    this.stack = document.querySelector(".toast-stack");
    if (!this.stack) {
      this.stack = document.createElement("div");
      this.stack.className = "toast-stack";
      this.stack.setAttribute("aria-live", "polite");
      document.body.appendChild(this.stack);
    }
  },

  show(message, type = "success", icon) {
    if (!this.stack) this.init();
    const icons = { success: "✓", error: "⚠", info: "ℹ", warn: "⚠" };
    const el = document.createElement("div");
    el.className = `toast toast--${type}`;
    el.innerHTML = `<span class="toast-icon">${icon || icons[type] || "✓"}</span><span>${message}</span>`;
    this.stack.appendChild(el);
    setTimeout(() => {
      el.classList.add("leaving");
      setTimeout(() => el.remove(), 200);
    }, 2600);
  },
};

document.addEventListener("DOMContentLoaded", () => Toast.init());

/* ---- Notification center (mock data) ---- */
const mockNotifications = [
  { icon: "🚚", key: "order_shipped", unread: true, time: "5 мин назад" },
  { icon: "💸", key: "price_drop", unread: true, time: "2 ч назад" },
  { icon: "💬", key: "seller_reply", unread: true, time: "вчера" },
  { icon: "↩️", key: "return_approved", unread: false, time: "2 дня назад" },
];

const notifTexts = {
  ru: {
    order_shipped: "Ваш заказ передан в доставку",
    price_drop: "Цена товара снизилась",
    seller_reply: "Продавец ответил на ваш вопрос",
    return_approved: "Возврат одобрен",
  },
  kk: {
    order_shipped: "Тапсырысыңыз жеткізуге берілді",
    price_drop: "Тауар бағасы төмендеді",
    seller_reply: "Сатушы сұрағыңызға жауап берді",
    return_approved: "Қайтару мақұлданды",
  },
  en: {
    order_shipped: "Your order is out for delivery",
    price_drop: "Price dropped on a saved item",
    seller_reply: "Seller replied to your question",
    return_approved: "Return approved",
  },
};

const NotificationCenter = {
  init() {
    const bell = document.querySelector("[data-notif-trigger]");
    const panel = document.querySelector("[data-notif-panel]");
    if (!bell || !panel) return;
    this.render(panel);
    bell.addEventListener("click", (e) => {
      e.stopPropagation();
      panel.classList.toggle("open");
      document.querySelector("[data-user-panel]")?.classList.remove("open");
    });
    panel.addEventListener("click", (e) => e.stopPropagation());
    document.addEventListener("click", () => panel.classList.remove("open"));
    document.addEventListener("langchange", () => this.render(panel));

    const markAll = panel.querySelector("[data-notif-mark-all]");
    markAll?.addEventListener("click", () => {
      mockNotifications.forEach((n) => (n.unread = false));
      this.render(panel);
      this.updateBadge();
    });
    this.updateBadge();
  },

  updateBadge() {
    const count = mockNotifications.filter((n) => n.unread).length;
    document.querySelectorAll("[data-notif-count]").forEach((b) => {
      b.textContent = count;
      b.style.display = count > 0 ? "flex" : "none";
    });
  },

  render(panel) {
    const lang = LanguageManager.get();
    const list = panel.querySelector(".notif-list");
    if (!list) return;
    list.innerHTML = mockNotifications
      .map(
        (n) => `
      <div class="notif-item ${n.unread ? "unread" : ""}">
        <div class="ni-icon">${n.icon}</div>
        <div>
          <div class="ni-text">${notifTexts[lang][n.key]}</div>
          <div class="ni-time">${n.time}</div>
        </div>
      </div>`
      )
      .join("");
  },
};

document.addEventListener("DOMContentLoaded", () => NotificationCenter.init());

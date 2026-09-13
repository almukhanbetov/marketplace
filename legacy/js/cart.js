/* ==========================================================================
   CART — state, drawer, page rendering
   ========================================================================== */

const Cart = {
  KEY: "mp_cart",

  get() {
    try {
      return JSON.parse(localStorage.getItem(this.KEY)) || [];
    } catch {
      return [];
    }
  },

  save(items) {
    localStorage.setItem(this.KEY, JSON.stringify(items));
    this.updateBadge();
    document.dispatchEvent(new CustomEvent("cartchange"));
  },

  count() {
    return this.get().reduce((sum, i) => sum + i.qty, 0);
  },

  has(productId) {
    return this.get().some((i) => i.id === productId);
  },

  add(productId, qty = 1) {
    const items = this.get();
    const existing = items.find((i) => i.id === productId);
    if (existing) {
      existing.qty += qty;
    } else {
      items.push({ id: productId, qty });
    }
    this.save(items);
    this.bumpIcon();
  },

  setQty(productId, qty) {
    let items = this.get();
    if (qty <= 0) {
      items = items.filter((i) => i.id !== productId);
    } else {
      const item = items.find((i) => i.id === productId);
      if (item) item.qty = qty;
    }
    this.save(items);
  },

  remove(productId) {
    this.save(this.get().filter((i) => i.id !== productId));
  },

  clear() {
    this.save([]);
  },

  totals() {
    const items = this.get();
    let subtotal = 0;
    let oldSubtotal = 0;
    items.forEach((i) => {
      const p = getProductById(i.id);
      if (!p) return;
      subtotal += p.price * i.qty;
      oldSubtotal += p.oldPrice * i.qty;
    });
    const discount = oldSubtotal - subtotal;
    const shipping = subtotal > 0 && subtotal < 20000 ? 1500 : 0;
    return { subtotal, discount, shipping, total: subtotal + shipping };
  },

  bumpIcon() {
    document.querySelectorAll("[data-cart-icon]").forEach((el) => {
      el.classList.add("bump");
      setTimeout(() => el.classList.remove("bump"), 400);
    });
  },

  updateBadge() {
    const count = this.count();
    document.querySelectorAll("[data-cart-count]").forEach((b) => {
      b.textContent = count;
      b.style.display = count > 0 ? "flex" : "none";
    });
  },

  groupBySeller() {
    const items = this.get();
    const groups = {};
    items.forEach((i) => {
      const p = getProductById(i.id);
      if (!p) return;
      if (!groups[p.seller]) groups[p.seller] = { seller: p.seller, rating: p.sellerRating, items: [] };
      groups[p.seller].items.push({ ...i, product: p });
    });
    return Object.values(groups);
  },
};

/* ---- Drawer rendering ---- */
function renderCartDrawer() {
  const body = document.querySelector("[data-cart-drawer-body]");
  if (!body) return;
  const items = Cart.get();

  if (!items.length) {
    body.innerHTML = `<div class="empty-state">
      <div class="empty-state__icon">🛒</div>
      <h3>${t("emptyCart")}</h3>
      <p>${t("emptyCartSub")}</p>
    </div>`;
  } else {
    body.innerHTML = items
      .map((i) => {
        const p = getProductById(i.id);
        if (!p) return "";
        return `
        <div class="cart-line" data-line="${p.id}">
          <img src="${p.image}" alt="${p.title}">
          <div>
            <div class="cart-line-title">${p.title}</div>
            <div class="cart-line-seller">${t("sellerLabel")}: ${p.seller}</div>
            <div class="qty-stepper">
              <button aria-label="-" data-qty-minus="${p.id}">−</button>
              <span>${i.qty}</span>
              <button aria-label="+" data-qty-plus="${p.id}">+</button>
            </div>
          </div>
          <div>
            <div class="cart-line-price">${formatPrice(p.price * i.qty)}</div>
            <button class="cart-line-remove" data-line-remove="${p.id}">✕</button>
          </div>
        </div>`;
      })
      .join("");
  }

  const totals = Cart.totals();
  const summary = document.querySelector("[data-cart-drawer-summary]");
  if (summary) {
    summary.innerHTML = `
      <div class="summary-row"><span>${t("items")}</span><span>${formatPrice(totals.subtotal + totals.discount)}</span></div>
      <div class="summary-row"><span>${t("discount")}</span><span class="value--discount">−${formatPrice(totals.discount)}</span></div>
      <div class="summary-row"><span>${t("shipping")}</span><span>${totals.shipping ? formatPrice(totals.shipping) : t("free")}</span></div>
      <div class="summary-row total"><span>${t("total")}</span><span>${formatPrice(totals.total)}</span></div>
      <a href="checkout.html" class="btn btn--primary btn--block btn--lg" ${!items.length ? 'style="pointer-events:none;opacity:.5"' : ""}>${t("checkout")}</a>
    `;
  }

  body.querySelectorAll("[data-qty-plus]").forEach((btn) =>
    btn.addEventListener("click", () => {
      const id = Number(btn.getAttribute("data-qty-plus"));
      const item = Cart.get().find((i) => i.id === id);
      Cart.setQty(id, (item?.qty || 0) + 1);
    })
  );
  body.querySelectorAll("[data-qty-minus]").forEach((btn) =>
    btn.addEventListener("click", () => {
      const id = Number(btn.getAttribute("data-qty-minus"));
      const item = Cart.get().find((i) => i.id === id);
      Cart.setQty(id, (item?.qty || 0) - 1);
    })
  );
  body.querySelectorAll("[data-line-remove]").forEach((btn) =>
    btn.addEventListener("click", () => {
      Cart.remove(Number(btn.getAttribute("data-line-remove")));
      Toast.show(t("emptyCart") === "" ? "" : "Товар удалён", "info", "🗑");
    })
  );
}

document.addEventListener("cartchange", () => {
  renderCartDrawer();
  if (typeof renderCartPage === "function") renderCartPage();
  updateAllProductCardStates();
});
document.addEventListener("langchange", () => {
  renderCartDrawer();
  if (typeof renderCartPage === "function") renderCartPage();
});
document.addEventListener("DOMContentLoaded", () => {
  Cart.updateBadge();
  renderCartDrawer();

  const cartTrigger = document.querySelector("[data-cart-trigger]");
  const cartDrawer = document.querySelector("[data-cart-drawer]");
  const cartBackdrop = document.querySelector("[data-cart-backdrop]");
  cartTrigger?.addEventListener("click", (e) => {
    e.preventDefault();
    DrawerManager.open("[data-cart-drawer]", "[data-cart-backdrop]");
  });
  document.querySelectorAll("[data-cart-close]").forEach((btn) =>
    btn.addEventListener("click", () => DrawerManager.close("[data-cart-drawer]", "[data-cart-backdrop]"))
  );
  cartBackdrop?.addEventListener("click", (e) => {
    if (e.target === cartBackdrop) DrawerManager.close("[data-cart-drawer]", "[data-cart-backdrop]");
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") DrawerManager.close("[data-cart-drawer]", "[data-cart-backdrop]");
  });
});

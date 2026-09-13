/* ==========================================================================
   PRODUCT CARD RENDERING + QUICK VIEW + RECENTLY VIEWED
   ========================================================================== */

function deliveryLabel(code) {
  if (code === "tomorrow") return t("deliveryTomorrow");
  if (code === "today") return t("deliveryToday");
  return t("delivery") + ": 2 " + (LanguageManager.get() === "en" ? "days" : "дня");
}

function productCardHTML(p) {
  const inCart = Cart.has(p.id);
  const cartItem = Cart.get().find((i) => i.id === p.id);
  const isFav = Favorites.has(p.id);
  return `
  <article class="product-card" data-product-card="${p.id}">
    <a href="product.html?id=${p.id}" class="pc-media" aria-label="${p.title}">
      <div class="pc-badges">
        ${p.badge === "sale" ? `<span class="badge badge--sale">−${p.discount}%</span>` : ""}
        ${p.badge === "new" ? `<span class="badge badge--new">${t("newArrivals").split(" ")[0]}</span>` : ""}
      </div>
      <img class="primary" src="${p.image}" alt="${p.title}" loading="lazy">
      <img class="secondary" src="${p.image2}" alt="" loading="lazy">
    </a>
    <button class="pc-fav ${isFav ? "active" : ""}" data-fav-toggle="${p.id}" aria-label="Favorite" aria-pressed="${isFav}">
      ${isFav ? "♥" : "♡"}
    </button>
    <div class="pc-quick">
      <button data-quickview="${p.id}">${t("quickView")}</button>
      <button data-compare-toggle="${p.id}">${t("compare")}</button>
    </div>
    <div class="pc-body">
      <div class="pc-rating"><span class="stars">★★★★★</span><b>${p.rating}</b>&middot; ${p.reviews} ${t("reviews")}</div>
      <div class="pc-brand">${p.brand}</div>
      <a href="product.html?id=${p.id}" class="pc-title">${p.title}</a>
      <div class="pc-price-row">
        <span class="pc-price">${formatPrice(p.price)}</span>
        <span class="pc-price-old">${formatPrice(p.oldPrice)}</span>
        <span class="pc-discount">−${p.discount}%</span>
      </div>
      <div class="pc-installment">${t("from")} <b>${formatPrice(p.installment)}</b> × 24</div>
      <div class="pc-delivery">🚚 ${deliveryLabel(p.delivery)}</div>
      <div class="pc-seller"><span>${t("sellerLabel")}: <b>${p.seller}</b></span><span class="stars">★${p.sellerRating}</span></div>
      <button class="pc-cart-btn ${inCart ? "in-cart" : ""}" data-cart-toggle="${p.id}" style="${inCart ? "display:none" : ""}">
        🛒 ${t("addToCart")}
      </button>
      <div class="pc-qty ${inCart ? "show" : ""}" data-pc-qty="${p.id}">
        <button data-pc-qty-minus="${p.id}">−</button>
        <span>${cartItem ? cartItem.qty : 1}</span>
        <button data-pc-qty-plus="${p.id}">+</button>
      </div>
    </div>
  </article>`;
}

function renderGrid(sel, list) {
  const el = document.querySelector(sel);
  if (!el) return;
  if (!list.length) {
    el.innerHTML = `<div class="empty-state" style="grid-column:1/-1">
      <div class="empty-state__icon">🔍</div>
      <h3>Ничего не найдено</h3>
    </div>`;
    return;
  }
  el.innerHTML = list.map(productCardHTML).join("");
}

function updateAllProductCardStates() {
  document.querySelectorAll("[data-product-card]").forEach((card) => {
    const id = Number(card.getAttribute("data-product-card"));
    const favBtn = card.querySelector("[data-fav-toggle]");
    const isFav = Favorites.has(id);
    if (favBtn) {
      favBtn.classList.toggle("active", isFav);
      favBtn.textContent = isFav ? "♥" : "♡";
      favBtn.setAttribute("aria-pressed", isFav);
    }
    const cartBtn = card.querySelector("[data-cart-toggle]");
    const qtyBox = card.querySelector("[data-pc-qty]");
    const inCart = Cart.has(id);
    const item = Cart.get().find((i) => i.id === id);
    if (cartBtn) cartBtn.style.display = inCart ? "none" : "flex";
    if (qtyBox) {
      qtyBox.classList.toggle("show", inCart);
      const span = qtyBox.querySelector("span");
      if (span && item) span.textContent = item.qty;
    }
  });
}

/* ---- Event delegation for all product-card actions ---- */
document.addEventListener("click", (e) => {
  const favBtn = e.target.closest("[data-fav-toggle]");
  if (favBtn) {
    e.preventDefault();
    Favorites.toggle(Number(favBtn.getAttribute("data-fav-toggle")));
    return;
  }
  const cartBtn = e.target.closest("[data-cart-toggle]");
  if (cartBtn) {
    e.preventDefault();
    const id = Number(cartBtn.getAttribute("data-cart-toggle"));
    Cart.add(id, 1);
    Toast.show(t("addedToCart"), "success", "✓");
    return;
  }
  const qtyPlus = e.target.closest("[data-pc-qty-plus]");
  if (qtyPlus) {
    e.preventDefault();
    const id = Number(qtyPlus.getAttribute("data-pc-qty-plus"));
    const item = Cart.get().find((i) => i.id === id);
    Cart.setQty(id, (item?.qty || 0) + 1);
    return;
  }
  const qtyMinus = e.target.closest("[data-pc-qty-minus]");
  if (qtyMinus) {
    e.preventDefault();
    const id = Number(qtyMinus.getAttribute("data-pc-qty-minus"));
    const item = Cart.get().find((i) => i.id === id);
    Cart.setQty(id, (item?.qty || 0) - 1);
    return;
  }
  const qvBtn = e.target.closest("[data-quickview]");
  if (qvBtn) {
    e.preventDefault();
    openQuickView(Number(qvBtn.getAttribute("data-quickview")));
    return;
  }
  const cmpBtn = e.target.closest("[data-compare-toggle]");
  if (cmpBtn) {
    e.preventDefault();
    toggleCompare(Number(cmpBtn.getAttribute("data-compare-toggle")));
    return;
  }
});

/* ---- Quick view ---- */
function openQuickView(id) {
  const p = getProductById(id);
  if (!p) return;
  const backdrop = document.getElementById("quickview-modal");
  if (!backdrop) return;
  const body = backdrop.querySelector(".modal-body");
  body.innerHTML = `
    <div class="quickview-grid">
      <div class="quickview-img"><img src="${p.image}" alt="${p.title}"></div>
      <div>
        <div class="pc-rating" style="margin-bottom:8px"><span class="stars">★★★★★</span><b>${p.rating}</b> &middot; ${p.reviews} ${t("reviews")}</div>
        <div class="pc-brand">${p.brand}</div>
        <h3 style="font-size:var(--fs-lg);font-weight:800;margin:6px 0 12px">${p.title}</h3>
        <div class="pc-price-row" style="margin-bottom:10px">
          <span class="pc-price" style="font-size:var(--fs-xl)">${formatPrice(p.price)}</span>
          <span class="pc-price-old">${formatPrice(p.oldPrice)}</span>
          <span class="pc-discount">−${p.discount}%</span>
        </div>
        <div class="pc-delivery" style="margin-bottom:14px">🚚 ${deliveryLabel(p.delivery)}</div>
        <div style="display:flex;gap:10px">
          <button class="btn btn--primary btn--lg" data-cart-toggle="${p.id}">🛒 ${t("addToCart")}</button>
          <a href="product.html?id=${p.id}" class="btn btn--outline btn--lg">${t("viewAll")}</a>
        </div>
      </div>
    </div>`;
  addRecentlyViewed(id);
  ModalManager.open("quickview-modal");
}

/* ---- Recently viewed ---- */
function addRecentlyViewed(id) {
  let list = JSON.parse(localStorage.getItem("mp_recent") || "[]");
  list = list.filter((x) => x !== id);
  list.unshift(id);
  list = list.slice(0, 10);
  localStorage.setItem("mp_recent", JSON.stringify(list));
}

function renderRecentlyViewed(sel) {
  const el = document.querySelector(sel);
  if (!el) return;
  const list = JSON.parse(localStorage.getItem("mp_recent") || "[]")
    .map((id) => getProductById(id))
    .filter(Boolean);
  const section = el.closest("[data-recent-section]");
  if (!list.length) {
    if (section) section.style.display = "none";
    return;
  }
  if (section) section.style.display = "";
  el.innerHTML = list.map(productCardHTML).join("");
}

/* ---- Compare ---- */
function toggleCompare(id) {
  let list = JSON.parse(localStorage.getItem("mp_compare") || "[]");
  if (list.includes(id)) {
    list = list.filter((x) => x !== id);
    Toast.show("Удалено из сравнения", "info", "✕");
  } else {
    if (list.length >= 4) {
      Toast.show("Можно сравнить максимум 4 товара", "warn", "⚠");
      return;
    }
    list.push(id);
    Toast.show("Добавлено к сравнению", "success", "✓");
  }
  localStorage.setItem("mp_compare", JSON.stringify(list));
  document.querySelectorAll("[data-compare-count]").forEach((b) => {
    b.textContent = list.length;
    b.style.display = list.length ? "flex" : "none";
  });
}

/* ---- Recommendations (simple mock: same category as favorites/recent) ---- */
function renderRecommendations(sel) {
  const el = document.querySelector(sel);
  if (!el) return;
  const seeds = [...Favorites.get(), ...JSON.parse(localStorage.getItem("mp_recent") || "[]")];
  let cats = seeds.map((id) => getProductById(id)?.category).filter(Boolean);
  if (!cats.length) cats = ["electronics", "fashion"];
  const pool = products.filter((p) => cats.includes(p.category));
  const list = (pool.length ? pool : products).slice(0, 6);
  el.innerHTML = list.map(productCardHTML).join("");
}

document.addEventListener("cartchange", updateAllProductCardStates);
document.addEventListener("favchange", updateAllProductCardStates);

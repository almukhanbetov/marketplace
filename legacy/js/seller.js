/* ==========================================================================
   SELLER DASHBOARD — products CRUD (mock), orders, sidebar nav
   ========================================================================== */

const SellerStore = {
  KEY: "mp_seller_products",

  seed() {
    if (localStorage.getItem(this.KEY)) return;
    const own = products.filter((p) => p.sellerId === "s1").slice(0, 9).map((p) => ({
      id: p.id,
      sku: "SKU-" + (1000 + p.id),
      title: p.title,
      category: p.category,
      price: p.price,
      oldPrice: p.oldPrice,
      stock: p.stock,
      sales: 20 + (p.id * 7) % 300,
      status: p.stock < 6 ? "low" : "active",
      image: p.image,
    }));
    localStorage.setItem(this.KEY, JSON.stringify(own));
  },

  get() {
    this.seed();
    try { return JSON.parse(localStorage.getItem(this.KEY)) || []; } catch { return []; }
  },

  save(list) {
    localStorage.setItem(this.KEY, JSON.stringify(list));
  },

  add(product) {
    const list = this.get();
    const id = Date.now();
    list.unshift({
      id,
      sku: "SKU-" + Math.floor(1000 + Math.random() * 9000),
      title: product.title,
      category: product.category,
      price: product.price,
      oldPrice: product.oldPrice || product.price,
      stock: product.stock,
      sales: 0,
      status: product.stock < 6 ? "low" : "active",
      image: product.image || svgImg(product.title.slice(0, 2).toUpperCase(), "#2b3a67", "#1b2440"),
    });
    this.save(list);
  },

  remove(id) {
    this.save(this.get().filter((p) => p.id !== id));
  },
};

const SellerOrders = {
  KEY: "mp_seller_orders",
  seed() {
    if (localStorage.getItem(this.KEY)) return;
    const statuses = ["new", "confirmed", "packed", "shipped", "delivered"];
    const list = Array.from({ length: 8 }).map((_, i) => ({
      id: "MK-2026-" + (10000 + i),
      customer: ["А. Ермеков", "Д. Смагулова", "Т. Ким", "Р. Абенова", "С. Ли"][i % 5],
      total: 25000 + i * 18000,
      status: statuses[i % statuses.length],
      date: `2026-08-${20 + (i % 9)}`,
      items: 1 + (i % 4),
    }));
    localStorage.setItem(this.KEY, JSON.stringify(list));
  },
  get() {
    this.seed();
    return JSON.parse(localStorage.getItem(this.KEY) || "[]");
  },
  save(list) { localStorage.setItem(this.KEY, JSON.stringify(list)); },
  setStatus(id, status) {
    const list = this.get();
    const o = list.find((x) => x.id === id);
    if (o) o.status = status;
    this.save(list);
  },
};

const statusLabels = {
  new: "Новый", confirmed: "Подтверждён", packed: "Собран", shipped: "В пути", delivered: "Доставлен", cancelled: "Отменён",
};
const statusClass = {
  new: "status-pill--new", confirmed: "status-pill--progress", packed: "status-pill--progress",
  shipped: "status-pill--progress", delivered: "status-pill--done", cancelled: "status-pill--cancel",
};

/* ---- Dashboard sidebar section switcher ---- */
function initDashNav() {
  const items = document.querySelectorAll("[data-dash-section]");
  const panels = document.querySelectorAll("[data-dash-panel]");
  items.forEach((item) => {
    item.addEventListener("click", (e) => {
      e.preventDefault();
      const target = item.getAttribute("data-dash-section");
      items.forEach((i) => i.classList.toggle("active", i === item));
      panels.forEach((p) => p.classList.toggle("active", p.getAttribute("data-dash-panel") === target));
      window.scrollTo({ top: 0, behavior: "smooth" });
    });
  });
}

/* ---- Products table ---- */
function renderSellerProductsTable() {
  const tbody = document.querySelector("[data-seller-products-tbody]");
  if (!tbody) return;
  const list = SellerStore.get();
  if (!list.length) {
    tbody.innerHTML = `<tr><td colspan="8"><div class="empty-state"><div class="empty-state__icon">📦</div><h3>Нет товаров</h3></div></td></tr>`;
    return;
  }
  tbody.innerHTML = list
    .map(
      (p) => `
    <tr>
      <td><img class="dt-thumb" src="${p.image}" alt=""></td>
      <td>${p.sku}</td>
      <td>${p.title}</td>
      <td>${p.category}</td>
      <td>${formatPrice(p.price)}</td>
      <td>${p.stock < 6 ? `<span class="badge badge--danger">Осталось ${p.stock}</span>` : p.stock}</td>
      <td>${p.sales}</td>
      <td><span class="status-pill ${p.status === "low" ? "status-pill--cancel" : "status-pill--done"}">${p.status === "low" ? "Мало на складе" : "Активен"}</span></td>
      <td class="row-actions"><button data-seller-product-delete="${p.id}" aria-label="Удалить">🗑</button></td>
    </tr>`
    )
    .join("");

  tbody.querySelectorAll("[data-seller-product-delete]").forEach((btn) =>
    btn.addEventListener("click", () => {
      SellerStore.remove(Number(btn.getAttribute("data-seller-product-delete")));
      renderSellerProductsTable();
      Toast.show("Товар удалён", "info", "🗑");
    })
  );
}

/* ---- Add product modal ---- */
function initAddProductForm() {
  const form = document.querySelector("[data-add-product-form]");
  if (!form) return;
  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const fd = new FormData(form);
    SellerStore.add({
      title: fd.get("title"),
      category: fd.get("category"),
      price: Number(fd.get("price")),
      oldPrice: Number(fd.get("oldPrice")) || Number(fd.get("price")),
      stock: Number(fd.get("stock")),
      image: fd.get("image") || "",
    });
    renderSellerProductsTable();
    ModalManager.close("add-product-modal");
    form.reset();
    Toast.show("Товар добавлен", "success", "✓");
  });
}

/* ---- Orders table ---- */
function renderSellerOrdersTable() {
  const tbody = document.querySelector("[data-seller-orders-tbody]");
  if (!tbody) return;
  const list = SellerOrders.get();
  tbody.innerHTML = list
    .map(
      (o) => `
    <tr>
      <td>${o.id}</td>
      <td>${o.customer}</td>
      <td>${o.items} шт.</td>
      <td>${formatPrice(o.total)}</td>
      <td>
        <select class="status-pill ${statusClass[o.status]}" data-order-status="${o.id}" style="appearance:none;padding-right:8px">
          ${Object.keys(statusLabels)
            .map((s) => `<option value="${s}" ${s === o.status ? "selected" : ""}>${statusLabels[s]}</option>`)
            .join("")}
        </select>
      </td>
      <td>${o.date}</td>
      <td class="row-actions"><button aria-label="Подробнее">👁</button></td>
    </tr>`
    )
    .join("");

  tbody.querySelectorAll("[data-order-status]").forEach((sel) =>
    sel.addEventListener("change", () => {
      SellerOrders.setStatus(sel.getAttribute("data-order-status"), sel.value);
      Toast.show("Статус заказа обновлён", "success", "✓");
    })
  );
}

document.addEventListener("DOMContentLoaded", () => {
  initDashNav();
  renderSellerProductsTable();
  initAddProductForm();
  renderSellerOrdersTable();
});

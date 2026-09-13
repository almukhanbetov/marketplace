/* ==========================================================================
   REUSABLE MODAL SYSTEM
   ========================================================================== */

const ModalManager = {
  openStack: [],

  init() {
    document.querySelectorAll("[data-modal-open]").forEach((btn) => {
      btn.addEventListener("click", () => this.open(btn.getAttribute("data-modal-open")));
    });
    document.querySelectorAll(".modal-backdrop").forEach((backdrop) => {
      backdrop.addEventListener("click", (e) => {
        if (e.target === backdrop) this.close(backdrop.id);
      });
      backdrop.querySelectorAll("[data-modal-close]").forEach((btn) => {
        btn.addEventListener("click", () => this.close(backdrop.id));
      });
    });
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && this.openStack.length) {
        this.close(this.openStack[this.openStack.length - 1]);
      }
    });
  },

  open(id) {
    const backdrop = document.getElementById(id);
    if (!backdrop) return;
    backdrop.classList.add("open");
    document.body.classList.add("no-scroll");
    this.openStack.push(id);
    const focusable = backdrop.querySelector("input, button, select, textarea");
    focusable?.focus();
    document.dispatchEvent(new CustomEvent("modalopen", { detail: { id } }));
  },

  close(id) {
    const backdrop = document.getElementById(id);
    if (!backdrop) return;
    backdrop.classList.remove("open");
    this.openStack = this.openStack.filter((x) => x !== id);
    if (!this.openStack.length) document.body.classList.remove("no-scroll");
  },

  closeAll() {
    document.querySelectorAll(".modal-backdrop.open").forEach((b) => b.classList.remove("open"));
    this.openStack = [];
    document.body.classList.remove("no-scroll");
  },
};

document.addEventListener("DOMContentLoaded", () => ModalManager.init());

/* ---- Generic drawer helper (cart drawer, filter drawer) ---- */
const DrawerManager = {
  open(drawerSel, backdropSel) {
    document.querySelector(drawerSel)?.classList.add("open");
    document.querySelector(backdropSel)?.classList.add("open");
    document.body.classList.add("no-scroll");
  },
  close(drawerSel, backdropSel) {
    document.querySelector(drawerSel)?.classList.remove("open");
    document.querySelector(backdropSel)?.classList.remove("open");
    document.body.classList.remove("no-scroll");
  },
};

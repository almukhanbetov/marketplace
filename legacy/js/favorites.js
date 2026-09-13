/* ==========================================================================
   FAVORITES — state + page rendering
   ========================================================================== */

const Favorites = {
  KEY: "mp_favorites",

  get() {
    try {
      return JSON.parse(localStorage.getItem(this.KEY)) || [];
    } catch {
      return [];
    }
  },

  has(id) {
    return this.get().includes(id);
  },

  toggle(id) {
    let list = this.get();
    let added;
    if (list.includes(id)) {
      list = list.filter((x) => x !== id);
      added = false;
    } else {
      list.push(id);
      added = true;
    }
    localStorage.setItem(this.KEY, JSON.stringify(list));
    this.updateBadge();
    document.dispatchEvent(new CustomEvent("favchange"));
    Toast.show(added ? t("addedToFav") : t("removedFromFav"), added ? "success" : "info", added ? "♡" : "✕");
    return added;
  },

  updateBadge() {
    const count = this.get().length;
    document.querySelectorAll("[data-fav-count]").forEach((b) => {
      b.textContent = count;
      b.style.display = count > 0 ? "flex" : "none";
    });
  },
};

document.addEventListener("DOMContentLoaded", () => Favorites.updateBadge());
document.addEventListener("favchange", () => {
  updateAllProductCardStates();
  if (typeof renderFavoritesPage === "function") renderFavoritesPage();
});

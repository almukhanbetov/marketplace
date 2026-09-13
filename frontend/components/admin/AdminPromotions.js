export default function AdminPromotions() {
  return (
    <div className="hero-promos" style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 16 }}>
      <div className="promo-card promo-card--a"><b>Главный баннер</b><span>Активна до 02.09.2026</span></div>
      <div className="promo-card promo-card--b"><b>Flash Sale недели</b><span>Активна, 42 товара</span></div>
      <div className="promo-card promo-card--a"><b>Скидки для новых</b><span>Черновик</span></div>
    </div>
  );
}

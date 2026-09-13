import Link from "next/link";

const NAV = [
  { key: "overview", icon: "📊", label: "Dashboard" },
  { key: "products", icon: "📦", label: "Товары" },
  { key: "orders", icon: "🧾", label: "Заказы" },
  { key: "inventory", icon: "🏬", label: "Склад" },
  { key: "pricing", icon: "💲", label: "Цены" },
  { key: "finance", icon: "💰", label: "Финансы" },
  { key: "analytics", icon: "📈", label: "Аналитика" },
  { key: "reviews", icon: "⭐", label: "Отзывы" },
  { key: "messages", icon: "💬", label: "Сообщения" },
  { key: "ads", icon: "📣", label: "Реклама" },
  { key: "settings", icon: "⚙️", label: "Настройки" },
];

export default function SellerSidebar({ section, onSelect }) {
  return (
    <aside className="dash-sidebar">
      <div className="dash-brand">
        <span className="logo-mark">N</span> Nova <span className="text-muted" style={{ fontWeight: 600, fontSize: "var(--fs-xs)" }}>Seller</span>
      </div>
      {NAV.map((item) => (
        <button
          key={item.key}
          className={`dash-nav-item ${section === item.key ? "active" : ""}`}
          onClick={() => onSelect(item.key)}
        >
          <span className="dn-icon">{item.icon}</span>
          {item.label}
        </button>
      ))}
      <div style={{ height: 1, background: "var(--border)", margin: "10px 4px" }} />
      <Link href="/" className="dash-nav-item">
        <span className="dn-icon">↩️</span>На витрину Nova
      </Link>
    </aside>
  );
}

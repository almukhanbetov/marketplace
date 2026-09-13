import Link from "next/link";

const NAV = [
  { key: "overview", icon: "📊", label: "Overview" },
  { key: "users", icon: "👥", label: "Users" },
  { key: "sellers", icon: "🏬", label: "Sellers" },
  { key: "products", icon: "📦", label: "Products" },
  { key: "categories", icon: "🗂️", label: "Categories" },
  { key: "orders", icon: "🧾", label: "Orders" },
  { key: "payments", icon: "💳", label: "Payments" },
  { key: "commissions", icon: "💠", label: "Commissions" },
  { key: "payouts", icon: "💸", label: "Payouts" },
  { key: "returns", icon: "↩️", label: "Returns" },
  { key: "reviews", icon: "⭐", label: "Reviews" },
  { key: "promotions", icon: "🎯", label: "Promotions" },
  { key: "analytics", icon: "📈", label: "Analytics" },
  { key: "settings", icon: "⚙️", label: "Settings" },
];

export default function AdminSidebar({ section, onSelect }) {
  return (
    <aside className="dash-sidebar">
      <div className="dash-brand">
        <span className="logo-mark">N</span> Nova <span className="text-muted" style={{ fontWeight: 600, fontSize: "var(--fs-xs)" }}>Admin</span>
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

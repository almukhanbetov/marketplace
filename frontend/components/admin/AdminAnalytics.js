import BarChart from "@/components/ui/BarChart";
import { categories } from "@/data/categories";
import { products } from "@/data/products";

export default function AdminAnalytics() {
  const data = categories.slice(0, 6).map((c) => ({
    label: c.icon,
    value: products.filter((p) => p.category === c.id).length || 1,
  }));

  return (
    <div className="chart-card">
      <h4 style={{ fontSize: "var(--fs-sm)", fontWeight: 700, marginBottom: 16 }}>Заказы по категориям</h4>
      <BarChart data={data} />
    </div>
  );
}

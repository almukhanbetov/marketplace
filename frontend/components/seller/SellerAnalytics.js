import BarChart from "@/components/ui/BarChart";

const FUNNEL = [
  { label: "Показы", value: 100 }, { label: "Клики", value: 42 },
  { label: "Корзина", value: 18 }, { label: "Заказ", value: 11 },
];

export default function SellerAnalytics() {
  return (
    <div className="chart-card">
      <h4 style={{ fontSize: "var(--fs-sm)", fontWeight: 700, marginBottom: 16 }}>Конверсия воронки</h4>
      <BarChart data={FUNNEL} />
    </div>
  );
}

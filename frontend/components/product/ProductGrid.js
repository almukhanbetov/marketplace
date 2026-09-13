import ProductCard from "@/components/product/ProductCard";

export default function ProductGrid({ products, emptyLabel = "Ничего не найдено", className = "grid-products" }) {
  if (!products.length) {
    return (
      <div className={className}>
        <div className="empty-state" style={{ gridColumn: "1/-1" }}>
          <div className="empty-state__icon">🔍</div>
          <h3>{emptyLabel}</h3>
        </div>
      </div>
    );
  }

  return (
    <div className={className}>
      {products.map((p) => (
        <ProductCard key={p.id} product={p} />
      ))}
    </div>
  );
}

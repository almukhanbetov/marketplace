import { getProducts } from "@/lib/api/products";
import HomeContent from "@/components/home/HomeContent";

async function safeGetProducts(params) {
  try {
    const { items } = await getProducts(params);
    return items;
  } catch {
    // One section's fetch failing shouldn't take down the whole homepage —
    // ProductGrid/ProductCarousel already render an empty state for [].
    return [];
  }
}

export default async function HomePage() {
  const [forYou, bestSellers, onSale, newArrivals] = await Promise.all([
    safeGetProducts({ limit: 12 }),
    safeGetProducts({ limit: 10, sort: "rating_desc" }),
    safeGetProducts({ limit: 12, sort: "discount_desc" }),
    safeGetProducts({ limit: 10, sort: "newest" }),
  ]);

  return <HomeContent forYou={forYou} bestSellers={bestSellers} onSale={onSale} newArrivals={newArrivals} />;
}

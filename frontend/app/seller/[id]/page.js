import { notFound } from "next/navigation";
import { getSeller, getSellerProducts } from "@/lib/api/sellers";
import { ApiError } from "@/lib/api/client";
import SellerPageContent from "@/components/seller/SellerPageContent";

async function loadSeller(id) {
  try {
    return await getSeller(id);
  } catch (err) {
    if (err instanceof ApiError && err.status === 404) return null;
    throw err;
  }
}

export async function generateMetadata({ params }) {
  const { id } = await params;
  const seller = await loadSeller(id);
  return { title: seller ? `${seller.name} — Nova Marketplace` : "Продавец не найден — Nova Marketplace" };
}

export default async function SellerPage({ params }) {
  const { id } = await params;
  const seller = await loadSeller(id);
  if (!seller) notFound();

  const { items: rawProducts } = await getSellerProducts(id, { limit: 24 });

  return <SellerPageContent seller={seller} rawProducts={rawProducts} />;
}

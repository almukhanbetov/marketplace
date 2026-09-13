import { notFound } from "next/navigation";
import { getProduct, getProductOffers } from "@/lib/api/products";
import { adaptOffer, adaptProductDetail } from "@/lib/api/adapters";
import { ApiError } from "@/lib/api/client";
import ProductPageContent from "@/components/product/ProductPageContent";

async function loadProduct(id) {
  try {
    return await getProduct(id);
  } catch (err) {
    if (err instanceof ApiError && err.status === 404) return null;
    throw err;
  }
}

export async function generateMetadata({ params }) {
  const { id } = await params;
  const product = await loadProduct(id);
  if (!product) return { title: "Товар не найден — Nova Marketplace" };
  return {
    title: `${product.name?.ru || product.slug} — Nova Marketplace`,
    description: "Страница товара Nova Marketplace: галерея, продавцы, отзывы и вопросы.",
  };
}

export default async function ProductPage({ params }) {
  const { id } = await params;
  const product = await loadProduct(id);
  if (!product) notFound();

  const rawOffers = await getProductOffers(id);

  return <ProductPageContent product={product} rawOffers={rawOffers} />;
}

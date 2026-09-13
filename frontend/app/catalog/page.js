import { Suspense } from "react";
import CatalogPage from "@/components/catalog/CatalogPage";

export const metadata = {
  title: "Каталог — Nova Marketplace",
  description: "Каталог товаров Nova с фильтрами по категориям, брендам, цене и продавцам.",
};

export default function Catalog() {
  return (
    <Suspense fallback={null}>
      <CatalogPage />
    </Suspense>
  );
}

"use client";

import { useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import ProductReviews from "@/components/product/ProductReviews";
import ProductQuestions, { MOCK_QUESTIONS } from "@/components/product/ProductQuestions";

export default function ProductTabs({ product }) {
  const { t } = useLanguage();
  const [tab, setTab] = useState("reviews");

  const specs = [
    ["Бренд", product.brand],
    ["Категория", product.category],
    ["Артикул", "NV-" + (1000 + product.id)],
    ["Гарантия", "12 месяцев"],
    ["Страна производства", "Импорт"],
  ];

  return (
    <div>
      <div className="tab-row">
        <button className={`tab-btn ${tab === "reviews" ? "active" : ""}`} onClick={() => setTab("reviews")}>
          {t("reviews")}
        </button>
        <button className={`tab-btn ${tab === "questions" ? "active" : ""}`} onClick={() => setTab("questions")}>
          {t("productQuestions")}
        </button>
        <button className={`tab-btn ${tab === "specs" ? "active" : ""}`} onClick={() => setTab("specs")}>
          Характеристики
        </button>
      </div>

      <div className={`tab-panel ${tab === "reviews" ? "active" : ""}`}>
        <ProductReviews product={product} />
      </div>

      <div className={`tab-panel ${tab === "questions" ? "active" : ""}`}>
        <ProductQuestions seller={product.seller} />
      </div>

      <div className={`tab-panel ${tab === "specs" ? "active" : ""}`}>
        <div className="info-card">
          <table className="data-table">
            <tbody>
              {specs.map(([k, v]) => (
                <tr key={k}>
                  <td style={{ color: "var(--text-2)", width: 240 }}>{k}</td>
                  <td>{v}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

export { MOCK_QUESTIONS };

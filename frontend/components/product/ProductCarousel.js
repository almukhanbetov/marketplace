"use client";

import { useRef } from "react";
import ProductCard from "@/components/product/ProductCard";

export default function ProductCarousel({ products, showStockBar = false }) {
  const trackRef = useRef(null);

  function scroll(dir) {
    trackRef.current?.scrollBy({ left: dir * 480, behavior: "smooth" });
  }

  return (
    <div className="carousel-wrap">
      <button className="carousel-nav carousel-nav--prev" aria-label="Назад" onClick={() => scroll(-1)}>
        ‹
      </button>
      <div className="carousel-track" ref={trackRef}>
        {products.map((p) => (
          <ProductCard key={p.id} product={p} showStockBar={showStockBar} />
        ))}
      </div>
      <button className="carousel-nav carousel-nav--next" aria-label="Вперёд" onClick={() => scroll(1)}>
        ›
      </button>
    </div>
  );
}

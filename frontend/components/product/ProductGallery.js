"use client";

import { useState } from "react";
import Modal from "@/components/ui/Modal";

export default function ProductGallery({ product }) {
  const images = product.images && product.images.length ? product.images : [product.image, product.image2].filter(Boolean);
  const [index, setIndex] = useState(0);
  const [fullscreen, setFullscreen] = useState(false);

  function go(delta) {
    setIndex((i) => (i + delta + images.length) % images.length);
  }

  return (
    <div>
      <div
        className="quickview-img"
        style={{ cursor: "zoom-in", position: "relative" }}
        onClick={() => setFullscreen(true)}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={images[index]} alt={product.title} />
        <button
          className="hero-arrow hero-arrow--prev"
          style={{ left: 8 }}
          aria-label="Предыдущее фото"
          onClick={(e) => {
            e.stopPropagation();
            go(-1);
          }}
        >
          ‹
        </button>
        <button
          className="hero-arrow hero-arrow--next"
          style={{ right: 8 }}
          aria-label="Следующее фото"
          onClick={(e) => {
            e.stopPropagation();
            go(1);
          }}
        >
          ›
        </button>
      </div>
      <div style={{ display: "flex", gap: 10, marginTop: 10 }}>
        {images.map((img, i) => (
          <button
            key={i}
            style={{
              width: 64,
              height: 64,
              borderRadius: 10,
              overflow: "hidden",
              border: `2px solid ${i === index ? "var(--accent)" : "var(--border)"}`,
              flexShrink: 0,
            }}
            onClick={() => setIndex(i)}
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={img} style={{ width: "100%", height: "100%", objectFit: "cover" }} alt="" />
          </button>
        ))}
      </div>

      <Modal open={fullscreen} onClose={() => setFullscreen(false)} title="Галерея" size="xl">
        <div style={{ display: "flex", justifyContent: "center" }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={images[index]}
            alt={product.title}
            style={{ maxHeight: "70vh", borderRadius: "var(--radius-md)", margin: "0 auto" }}
          />
        </div>
      </Modal>
    </div>
  );
}

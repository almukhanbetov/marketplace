"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useLanguage } from "@/context/LanguageContext";

const SLIDES = [
  {
    eyebrowKey: "flashSale",
    titleKey: "heroTitle",
    subtitleKey: "heroSubtitle",
    ctaKey: "shopNow",
    href: "/catalog?cat=electronics&sort=discount",
  },
  {
    eyebrow: { ru: "Новая коллекция", kk: "Жаңа коллекция", en: "New collection" },
    title: { ru: "Стиль, который выделяет", kk: "Ерекшелейтін стиль", en: "Style that stands out" },
    subtitle: {
      ru: "Модные новинки сезона от 200+ проверенных продавцов.",
      kk: "200+ тексерілген сатушыдан маусымның сәнді жаңалықтары.",
      en: "This season's fashion picks from 200+ trusted sellers.",
    },
    cta: { ru: "Перейти в раздел", kk: "Бөлімге өту", en: "Browse the section" },
    href: "/catalog?cat=fashion",
  },
  {
    eyebrow: { ru: "Для дома", kk: "Үй үшін", en: "For your home" },
    title: { ru: "Уют начинается здесь", kk: "Жайлылық осыдан басталады", en: "Comfort starts here" },
    subtitle: {
      ru: "Мебель, техника и décor с доставкой за 24 часа.",
      kk: "Жиһаз, техника және декор 24 сағат ішінде жеткізіледі.",
      en: "Furniture, appliances and décor delivered in 24 hours.",
    },
    cta: { ru: "Выбрать товары", kk: "Тауарларды таңдау", en: "Shop now" },
    href: "/catalog?cat=home",
  },
];

export default function HeroSlider() {
  const { t, lang } = useLanguage();
  const [index, setIndex] = useState(0);
  const rootRef = useRef(null);
  const timerRef = useRef(null);
  const touchXRef = useRef(null);

  function go(i) {
    setIndex((i + SLIDES.length) % SLIDES.length);
  }
  function next() {
    setIndex((i) => (i + 1) % SLIDES.length);
  }
  function prev() {
    setIndex((i) => (i - 1 + SLIDES.length) % SLIDES.length);
  }

  function play() {
    stop();
    timerRef.current = setInterval(() => setIndex((i) => (i + 1) % SLIDES.length), 5000);
  }
  function stop() {
    if (timerRef.current) clearInterval(timerRef.current);
  }

  useEffect(() => {
    play();
    return stop;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="hero-grid">
      <div className="hero-banner" ref={rootRef} onMouseEnter={stop} onMouseLeave={play}>
        {SLIDES.map((slide, i) => (
          <div
            className={`hero-slide ${i === index ? "active" : ""}`}
            key={i}
            onTouchStart={(e) => (touchXRef.current = e.touches[0].clientX)}
            onTouchEnd={(e) => {
              if (touchXRef.current === null) return;
              const dx = e.changedTouches[0].clientX - touchXRef.current;
              if (Math.abs(dx) > 40) (dx < 0 ? next() : prev());
              touchXRef.current = null;
            }}
          >
            <span className="eyebrow">{slide.eyebrowKey ? t(slide.eyebrowKey) : slide.eyebrow[lang]}</span>
            <h1>{slide.titleKey ? t(slide.titleKey) : slide.title[lang]}</h1>
            <p>{slide.subtitleKey ? t(slide.subtitleKey) : slide.subtitle[lang]}</p>
            <Link href={slide.href} className="btn btn--accent btn--lg">
              {slide.ctaKey ? t(slide.ctaKey) : slide.cta[lang]}
            </Link>
          </div>
        ))}
        <button
          className="hero-arrow hero-arrow--prev"
          aria-label="Предыдущий баннер"
          onClick={() => {
            prev();
            play();
          }}
        >
          ‹
        </button>
        <button
          className="hero-arrow hero-arrow--next"
          aria-label="Следующий баннер"
          onClick={() => {
            next();
            play();
          }}
        >
          ›
        </button>
        <div className="hero-dots">
          {SLIDES.map((_, i) => (
            <button
              key={i}
              className={i === index ? "active" : ""}
              aria-label={`Слайд ${i + 1}`}
              onClick={() => {
                go(i);
                play();
              }}
            />
          ))}
        </div>
      </div>
      <div className="hero-promos">
        <Link href="/catalog?cat=computers" className="promo-card promo-card--a">
          <b>Ноутбуки для работы</b>
          <span>Рассрочка 0% на 24 месяца</span>
        </Link>
        <Link href="/catalog?sort=new" className="promo-card promo-card--b">
          <b>Только что в каталоге</b>
          <span>1200+ новых товаров на этой неделе</span>
        </Link>
      </div>
    </div>
  );
}

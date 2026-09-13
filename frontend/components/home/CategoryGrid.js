"use client";

import Link from "next/link";
import { useLanguage } from "@/context/LanguageContext";
import { homeCategories } from "@/data/categories";

export default function CategoryGrid() {
  const { lang } = useLanguage();

  return (
    <div className="grid-categories">
      {homeCategories.map((c, i) => (
        <Link className="cat-tile" href={`/catalog?cat=${c.cat}`} key={i}>
          <div className="cat-tile-img">{c.icon}</div>
          <span>{c.label[lang]}</span>
        </Link>
      ))}
    </div>
  );
}

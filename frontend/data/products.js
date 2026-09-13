import { img } from "@/lib/placeholder";
import { sellers } from "@/data/sellers";

export const deliveryOptions = ["tomorrow", "today", "2days"];

const rawProducts = [
  { title: "iPhone 17 Pro 256GB", brand: "Apple", category: "electronics", price: 620000, oldPrice: 699000, sellerIdx: 0 },
  { title: "Galaxy S25 Ultra 512GB", brand: "Samsung", category: "electronics", price: 540000, oldPrice: 610000, sellerIdx: 3 },
  { title: "Pixel 10 Pro 256GB", brand: "Google", category: "electronics", price: 480000, oldPrice: 520000, sellerIdx: 0 },
  { title: "Xiaomi 15 Ultra", brand: "Xiaomi", category: "electronics", price: 390000, oldPrice: 450000, sellerIdx: 3 },
  { title: "AirPods Pro 3", brand: "Apple", category: "electronics", price: 98000, oldPrice: 120000, sellerIdx: 0 },
  { title: "OLED TV 65\" C5", brand: "LG", category: "electronics", price: 780000, oldPrice: 920000, sellerIdx: 1 },
  { title: "QLED TV 55\" Neo", brand: "Samsung", category: "electronics", price: 520000, oldPrice: 610000, sellerIdx: 1 },
  { title: "Watch Ultra 3", brand: "Apple", category: "electronics", price: 260000, oldPrice: 290000, sellerIdx: 0 },
  { title: "WH-1000XM6 Наушники", brand: "Sony", category: "electronics", price: 165000, oldPrice: 195000, sellerIdx: 3 },
  { title: "MacBook Pro 14\" M5", brand: "Apple", category: "computers", price: 1150000, oldPrice: 1280000, sellerIdx: 0 },
  { title: "MacBook Air 15\" M4", brand: "Apple", category: "computers", price: 780000, oldPrice: 850000, sellerIdx: 0 },
  { title: "ROG Zephyrus G16", brand: "Asus", category: "computers", price: 920000, oldPrice: 1050000, sellerIdx: 3 },
  { title: "XPS 15 OLED", brand: "Dell", category: "computers", price: 860000, oldPrice: 980000, sellerIdx: 3 },
  { title: "UltraGear 27\" 240Hz", brand: "LG", category: "computers", price: 210000, oldPrice: 250000, sellerIdx: 1 },
  { title: "Механическая клавиатура K10", brand: "Logitech", category: "computers", price: 42000, oldPrice: 54000, sellerIdx: 4 },
  { title: "Пуховик премиум Aria", brand: "Zarina", category: "fashion", price: 68000, oldPrice: 98000, sellerIdx: 2 },
  { title: "Кожаная куртка Milano", brand: "Massimo", category: "fashion", price: 145000, oldPrice: 185000, sellerIdx: 2 },
  { title: "Платье вечернее Noir", brand: "Letique", category: "fashion", price: 54000, oldPrice: 76000, sellerIdx: 2 },
  { title: "Сумка кожаная Aurora", brand: "Guess", category: "fashion", price: 89000, oldPrice: 120000, sellerIdx: 2 },
  { title: "Худи оверсайз Basic", brand: "H&M", category: "fashion", price: 19500, oldPrice: 27000, sellerIdx: 2 },
  { title: "Air Max Pulse", brand: "Nike", category: "shoes", price: 62000, oldPrice: 78000, sellerIdx: 5 },
  { title: "Ultraboost 24", brand: "Adidas", category: "shoes", price: 71000, oldPrice: 89000, sellerIdx: 5 },
  { title: "Классические туфли Oxford", brand: "Ecco", category: "shoes", price: 58000, oldPrice: 74000, sellerIdx: 2 },
  { title: "Зимние ботинки TrekMax", brand: "Columbia", category: "shoes", price: 47000, oldPrice: 63000, sellerIdx: 5 },
  { title: "Набор для ухода GlowSet", brand: "La Roche-Posay", category: "beauty", price: 32000, oldPrice: 41000, sellerIdx: 4 },
  { title: "Парфюм Velvet Oud 100ml", brand: "Chanel", category: "beauty", price: 78000, oldPrice: 95000, sellerIdx: 4 },
  { title: "Палетка теней Prime", brand: "MAC", category: "beauty", price: 24500, oldPrice: 31000, sellerIdx: 4 },
  { title: "Диван модульный Loft", brand: "IKEA", category: "home", price: 340000, oldPrice: 410000, sellerIdx: 1 },
  { title: "Робот-пылесос CleanBot X9", brand: "Xiaomi", category: "home", price: 145000, oldPrice: 180000, sellerIdx: 1 },
  { title: "Кофемашина AromaTop", brand: "DeLonghi", category: "home", price: 210000, oldPrice: 260000, sellerIdx: 1 },
  { title: "Комплект постельного белья Silk", brand: "Togas", category: "home", price: 38000, oldPrice: 49000, sellerIdx: 1 },
  { title: "Видеорегистратор DriveEye 4K", brand: "70mai", category: "auto", price: 34000, oldPrice: 45000, sellerIdx: 6 },
  { title: "Автомобильный компрессор PowerAir", brand: "Bosch", category: "auto", price: 22000, oldPrice: 29000, sellerIdx: 6 },
  { title: "Чехлы универсальные ComfortFit", brand: "AutoStyle", category: "auto", price: 28000, oldPrice: 36000, sellerIdx: 6 },
  { title: "Беговая дорожка ProRun T5", brand: "NordicTrack", category: "sport", price: 480000, oldPrice: 580000, sellerIdx: 5 },
  { title: "Гантели наборные 20кг", brand: "Reebok", category: "sport", price: 45000, oldPrice: 58000, sellerIdx: 5 },
  { title: "Велосипед горный Trail X", brand: "Merida", category: "sport", price: 320000, oldPrice: 380000, sellerIdx: 5 },
  { title: "Конструктор GalaxyBricks 1200pc", brand: "LEGO", category: "kids", price: 42000, oldPrice: 54000, sellerIdx: 7 },
  { title: "Коляска 3в1 CityComfort", brand: "Cybex", category: "kids", price: 285000, oldPrice: 340000, sellerIdx: 7 },
  { title: "Электромобиль детский RaceKid", brand: "BabyRide", category: "kids", price: 165000, oldPrice: 210000, sellerIdx: 7 },
];

export const products = rawProducts.map((p, i) => {
  const id = i + 1;
  const discount = Math.round((1 - p.price / p.oldPrice) * 100);
  const rating = +(4.3 + (i % 6) * 0.11).toFixed(1);
  const reviews = 40 + (i * 37) % 900;
  const seller = sellers[p.sellerIdx];
  const stock = 3 + (i * 13) % 60;
  const delivery = deliveryOptions[i % deliveryOptions.length];
  const initials = p.brand.slice(0, 2).toUpperCase();
  return {
    id,
    title: p.title,
    brand: p.brand,
    category: p.category,
    price: p.price,
    oldPrice: p.oldPrice,
    discount,
    rating,
    reviews,
    image: img(id, initials),
    image2: img(id + 4, initials),
    seller: seller.name,
    sellerId: seller.id,
    sellerRating: seller.rating,
    stock,
    delivery,
    installment: Math.round(p.price / 24),
    colors: ["#2a2d34", "#4f8dff", "#ff5c72", "#f3f4f6"].slice(0, 2 + (i % 3)),
    sizes: ["fashion", "shoes"].includes(p.category) ? ["S", "M", "L", "XL"] : null,
    badge: i % 7 === 0 ? "new" : discount >= 20 ? "sale" : null,
    flashSale: i % 5 === 0,
    flashSoldPct: 30 + (i * 17) % 65,
    tags: [p.category, p.brand.toLowerCase()],
  };
});

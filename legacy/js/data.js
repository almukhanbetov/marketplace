/* ==========================================================================
   MOCK DATA — products, sellers, categories
   ========================================================================== */

function xmlEscape(str) {
  return String(str).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function svgImg(label, c1, c2) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600">
    <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${c1}"/><stop offset="1" stop-color="${c2}"/>
    </linearGradient></defs>
    <rect width="600" height="600" fill="url(#g)"/>
    <text x="300" y="325" font-family="Arial, sans-serif" font-size="120" font-weight="700"
      fill="rgba(255,255,255,.92)" text-anchor="middle">${xmlEscape(label)}</text>
  </svg>`;
  return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
}

const PALETTES = [
  ["#2b3a67", "#1b2440"], ["#3a2b58", "#241a3a"], ["#1e4b4b", "#123030"],
  ["#4b2b3a", "#2e1a24"], ["#2b4b2f", "#1a2e1c"], ["#4b3a1e", "#2e2412"],
  ["#2b3f4b", "#1a262e"], ["#3f2b4b", "#26192e"],
];

function img(id, letters) {
  const p = PALETTES[id % PALETTES.length];
  return svgImg(letters, p[0], p[1]);
}

const sellers = [
  { id: "s1", name: "TechStore", rating: 4.9, sales: 12430, years: 4, positive: 98, followers: 8200 },
  { id: "s2", name: "HomeComfort", rating: 4.8, sales: 7600, years: 3, positive: 96, followers: 4100 },
  { id: "s3", name: "StyleHub", rating: 4.7, sales: 15200, years: 5, positive: 95, followers: 11300 },
  { id: "s4", name: "GadgetPro", rating: 4.6, sales: 5400, years: 2, positive: 93, followers: 2600 },
  { id: "s5", name: "BeautyLab", rating: 4.9, sales: 9800, years: 3, positive: 97, followers: 6700 },
  { id: "s6", name: "SportZone", rating: 4.8, sales: 6300, years: 4, positive: 96, followers: 3900 },
  { id: "s7", name: "AutoPlus", rating: 4.5, sales: 3100, years: 2, positive: 91, followers: 1500 },
  { id: "s8", name: "KidsWorld", rating: 4.9, sales: 8900, years: 5, positive: 98, followers: 5200 },
];

const categories = [
  { id: "electronics", icon: "📱", label: { ru: "Электроника", kk: "Электроника", en: "Electronics" },
    sub: [
      { ru: "Смартфоны", kk: "Смартфондар", en: "Smartphones" },
      { ru: "Телевизоры", kk: "Теледидарлар", en: "TVs" },
      { ru: "Наушники", kk: "Құлаққаптар", en: "Headphones" },
      { ru: "Умные часы", kk: "Смарт сағаттар", en: "Smartwatches" },
    ] },
  { id: "computers", icon: "💻", label: { ru: "Компьютеры", kk: "Компьютерлер", en: "Computers" },
    sub: [
      { ru: "Ноутбуки", kk: "Ноутбуктар", en: "Laptops" },
      { ru: "Мониторы", kk: "Мониторлар", en: "Monitors" },
      { ru: "Комплектующие", kk: "Құрамдастар", en: "Components" },
      { ru: "Периферия", kk: "Перифериялар", en: "Peripherals" },
    ] },
  { id: "fashion", icon: "👗", label: { ru: "Одежда", kk: "Киім", en: "Fashion" },
    sub: [
      { ru: "Женская одежда", kk: "Әйелдер киімі", en: "Women" },
      { ru: "Мужская одежда", kk: "Ерлер киімі", en: "Men" },
      { ru: "Аксессуары", kk: "Аксессуарлар", en: "Accessories" },
      { ru: "Сумки", kk: "Сөмкелер", en: "Bags" },
    ] },
  { id: "shoes", icon: "👟", label: { ru: "Обувь", kk: "Аяқ киім", en: "Shoes" },
    sub: [
      { ru: "Кроссовки", kk: "Кроссовкалар", en: "Sneakers" },
      { ru: "Ботинки", kk: "Ботинкалар", en: "Boots" },
      { ru: "Туфли", kk: "Туфлилер", en: "Formal" },
    ] },
  { id: "beauty", icon: "💄", label: { ru: "Красота", kk: "Сұлулық", en: "Beauty" },
    sub: [
      { ru: "Уход за лицом", kk: "Бет күтімі", en: "Skincare" },
      { ru: "Парфюмерия", kk: "Парфюмерия", en: "Fragrance" },
      { ru: "Макияж", kk: "Макияж", en: "Makeup" },
    ] },
  { id: "home", icon: "🏠", label: { ru: "Дом", kk: "Үй", en: "Home" },
    sub: [
      { ru: "Мебель", kk: "Жиһаз", en: "Furniture" },
      { ru: "Текстиль", kk: "Тоқыма", en: "Textile" },
      { ru: "Кухня", kk: "Ас үй", en: "Kitchen" },
      { ru: "Освещение", kk: "Жарықтандыру", en: "Lighting" },
    ] },
  { id: "auto", icon: "🚗", label: { ru: "Автотовары", kk: "Авто тауарлар", en: "Auto" },
    sub: [
      { ru: "Аксессуары", kk: "Аксессуарлар", en: "Accessories" },
      { ru: "Электроника", kk: "Электроника", en: "Electronics" },
      { ru: "Уход", kk: "Күтім", en: "Care" },
    ] },
  { id: "sport", icon: "🏋️", label: { ru: "Спорт", kk: "Спорт", en: "Sport" },
    sub: [
      { ru: "Тренажёры", kk: "Тренажерлер", en: "Fitness" },
      { ru: "Одежда", kk: "Киім", en: "Apparel" },
      { ru: "Инвентарь", kk: "Мүкәммал", en: "Equipment" },
    ] },
  { id: "kids", icon: "🧸", label: { ru: "Детям", kk: "Балаларға", en: "Kids" },
    sub: [
      { ru: "Игрушки", kk: "Ойыншықтар", en: "Toys" },
      { ru: "Одежда", kk: "Киім", en: "Clothing" },
      { ru: "Коляски", kk: "Арбашалар", en: "Strollers" },
    ] },
  { id: "grocery", icon: "🛒", label: { ru: "Продукты", kk: "Азық-түлік", en: "Grocery" },
    sub: [
      { ru: "Напитки", kk: "Сусындар", en: "Drinks" },
      { ru: "Снеки", kk: "Снектер", en: "Snacks" },
      { ru: "Бакалея", kk: "Бакалея", en: "Pantry" },
    ] },
];

const homeCategories = [
  { cat: "electronics", icon: "📱", label: { ru: "Смартфоны", kk: "Смартфондар", en: "Smartphones" } },
  { cat: "computers", icon: "💻", label: { ru: "Ноутбуки", kk: "Ноутбуктар", en: "Laptops" } },
  { cat: "electronics", icon: "📺", label: { ru: "Телевизоры", kk: "Теледидарлар", en: "TVs" } },
  { cat: "fashion", icon: "👗", label: { ru: "Одежда", kk: "Киім", en: "Clothing" } },
  { cat: "shoes", icon: "👟", label: { ru: "Обувь", kk: "Аяқ киім", en: "Shoes" } },
  { cat: "home", icon: "🏠", label: { ru: "Дом", kk: "Үй", en: "Home" } },
  { cat: "beauty", icon: "💄", label: { ru: "Красота", kk: "Сұлулық", en: "Beauty" } },
  { cat: "auto", icon: "🚗", label: { ru: "Авто", kk: "Авто", en: "Auto" } },
  { cat: "sport", icon: "🏋️", label: { ru: "Спорт", kk: "Спорт", en: "Sport" } },
  { cat: "kids", icon: "🧸", label: { ru: "Детям", kk: "Балаларға", en: "Kids" } },
];

const deliveryOptions = ["tomorrow", "today", "2days"];

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

const productNames = { ru: {}, kk: {}, en: {} };

const products = rawProducts.map((p, i) => {
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

function getOffersForProduct(product) {
  const others = sellers.filter((s) => s.id !== product.sellerId).slice(0, 2);
  const base = product.price;
  const list = [
    { seller: product.seller, price: base, rating: product.sellerRating, delivery: product.delivery },
    { seller: others[0].name, price: Math.round(base * 1.02 / 1000) * 1000, rating: others[0].rating, delivery: "today" },
    { seller: others[1].name, price: Math.round(base * 0.985 / 1000) * 1000, rating: others[1].rating, delivery: "2days" },
  ];
  return list.sort((a, b) => a.price - b.price);
}

function getProductById(id) {
  return products.find((p) => p.id === Number(id));
}

function getSellerById(id) {
  return sellers.find((s) => s.id === id);
}

function formatPrice(n) {
  return n.toLocaleString("ru-RU").replace(/,/g, " ") + " ₸";
}

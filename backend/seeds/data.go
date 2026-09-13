package seeds

// Static demo data. Names/categories/sellers/products are deliberately
// aligned with frontend/data/*.js (products.js, categories.js, sellers.js)
// per the Stage 2 instructions — same catalog, now living in PostgreSQL
// instead of a JS array. The frontend itself is not touched.

type userSeed struct {
	Email    string
	Phone    string
	FullName string
	Role     string // customer | seller | admin
}

var users = []userSeed{
	// admin
	{Email: "admin@nova.kz", Phone: "+77010000001", FullName: "Nova Admin", Role: "admin"},

	// one user per seller account (role=seller)
	{Email: "techstore@nova.kz", Phone: "+77010000010", FullName: "Ерлан Ахметов", Role: "seller"},
	{Email: "homecomfort@nova.kz", Phone: "+77010000011", FullName: "Динара Смагулова", Role: "seller"},
	{Email: "stylehub@nova.kz", Phone: "+77010000012", FullName: "Асель Жаксыбекова", Role: "seller"},
	{Email: "gadgetpro@nova.kz", Phone: "+77010000013", FullName: "Тимур Ким", Role: "seller"},
	{Email: "beautylab@nova.kz", Phone: "+77010000014", FullName: "Сара Ли", Role: "seller"},
	{Email: "sportzone@nova.kz", Phone: "+77010000015", FullName: "Данияр Каримов", Role: "seller"},
	{Email: "autoplus@nova.kz", Phone: "+77010000016", FullName: "Рустем Абенов", Role: "seller"},
	{Email: "kidsworld@nova.kz", Phone: "+77010000017", FullName: "Айгерим Нурланова", Role: "seller"},

	// customer buyers
	{Email: "aigerim@example.com", Phone: "+77011234567", FullName: "Айгерим Ким", Role: "customer"},
	{Email: "nurlan@example.com", Phone: "+77012345678", FullName: "Нурлан Бекенов", Role: "customer"},
	{Email: "saltanat@example.com", Phone: "+77013456789", FullName: "Салтанат Рахимова", Role: "customer"},
}

type sellerSeed struct {
	Slug        string
	Name        string
	UserEmail   string
	Description string
	Rating      string
	ReviewCount int
	IsVerified  bool
}

var sellers = []sellerSeed{
	{Slug: "techstore", Name: "TechStore", UserEmail: "techstore@nova.kz", Description: "Официальный продавец электроники Apple, Samsung, Google и Sony.", Rating: "4.90", ReviewCount: 1243, IsVerified: true},
	{Slug: "homecomfort", Name: "HomeComfort", UserEmail: "homecomfort@nova.kz", Description: "Мебель, техника для дома и décor с доставкой по Казахстану.", Rating: "4.80", ReviewCount: 760, IsVerified: true},
	{Slug: "stylehub", Name: "StyleHub", UserEmail: "stylehub@nova.kz", Description: "Модная одежда, обувь и аксессуары от проверенных брендов.", Rating: "4.70", ReviewCount: 1520, IsVerified: true},
	{Slug: "gadgetpro", Name: "GadgetPro", UserEmail: "gadgetpro@nova.kz", Description: "Гаджеты и компьютерная техника нового поколения.", Rating: "4.60", ReviewCount: 540, IsVerified: false},
	{Slug: "beautylab", Name: "BeautyLab", UserEmail: "beautylab@nova.kz", Description: "Косметика и уход за собой от мировых брендов.", Rating: "4.90", ReviewCount: 980, IsVerified: true},
	{Slug: "sportzone", Name: "SportZone", UserEmail: "sportzone@nova.kz", Description: "Спортивный инвентарь и одежда для активной жизни.", Rating: "4.80", ReviewCount: 630, IsVerified: true},
	{Slug: "autoplus", Name: "AutoPlus", UserEmail: "autoplus@nova.kz", Description: "Автотовары, электроника и аксессуары для автомобиля.", Rating: "4.50", ReviewCount: 310, IsVerified: false},
	{Slug: "kidsworld", Name: "KidsWorld", UserEmail: "kidsworld@nova.kz", Description: "Игрушки, одежда и товары для детей всех возрастов.", Rating: "4.90", ReviewCount: 890, IsVerified: true},
}

type categorySeed struct {
	Slug                   string
	ParentSlug             string // "" = root category
	NameRU, NameKK, NameEN string
	SortOrder              int
}

var categories = []categorySeed{
	{Slug: "electronics", NameRU: "Электроника", NameKK: "Электроника", NameEN: "Electronics", SortOrder: 1},
	{Slug: "computers", NameRU: "Компьютеры", NameKK: "Компьютерлер", NameEN: "Computers", SortOrder: 2},
	{Slug: "fashion", NameRU: "Одежда", NameKK: "Киім", NameEN: "Fashion", SortOrder: 3},
	{Slug: "shoes", NameRU: "Обувь", NameKK: "Аяқ киім", NameEN: "Shoes", SortOrder: 4},
	{Slug: "beauty", NameRU: "Красота", NameKK: "Сұлулық", NameEN: "Beauty", SortOrder: 5},
	{Slug: "home", NameRU: "Дом", NameKK: "Үй", NameEN: "Home", SortOrder: 6},
	{Slug: "auto", NameRU: "Автотовары", NameKK: "Авто тауарлар", NameEN: "Auto", SortOrder: 7},
	{Slug: "sport", NameRU: "Спорт", NameKK: "Спорт", NameEN: "Sport", SortOrder: 8},
	{Slug: "kids", NameRU: "Детям", NameKK: "Балаларға", NameEN: "Kids", SortOrder: 9},
	{Slug: "grocery", NameRU: "Продукты", NameKK: "Азық-түлік", NameEN: "Grocery", SortOrder: 10},

	// A couple of child categories to demonstrate the parent_id tree works,
	// matching the subcategory labels used in the frontend mega-menu.
	{Slug: "smartphones", ParentSlug: "electronics", NameRU: "Смартфоны", NameKK: "Смартфондар", NameEN: "Smartphones", SortOrder: 1},
	{Slug: "tvs", ParentSlug: "electronics", NameRU: "Телевизоры", NameKK: "Теледидарлар", NameEN: "TVs", SortOrder: 2},
	{Slug: "laptops", ParentSlug: "computers", NameRU: "Ноутбуки", NameKK: "Ноутбуктар", NameEN: "Laptops", SortOrder: 1},
}

type productSeed struct {
	Slug                   string
	CategorySlug           string
	Brand                  string
	NameRU, NameKK, NameEN string
	Rating                 string
	ReviewCount            int
	Price                  string // primary offer price
	OldPrice               string // primary offer old price
	PrimarySellerSlug      string
	DeliveryDays           int // primary offer delivery days
}

// 40 products ported from frontend/data/products.js (rawProducts), enriched
// with kk/en names. Brand/model names that are already international
// (iPhone, MacBook, Air Max, ...) are intentionally identical across
// languages — translating a model name would be incorrect, not "meaningful".
var products = []productSeed{
	{Slug: "iphone-17-pro-256gb", CategorySlug: "electronics", Brand: "Apple", NameRU: "iPhone 17 Pro 256GB", NameKK: "iPhone 17 Pro 256GB", NameEN: "iPhone 17 Pro 256GB", Rating: "4.30", ReviewCount: 928, Price: "620000.00", OldPrice: "699000.00", PrimarySellerSlug: "techstore", DeliveryDays: 1},
	{Slug: "galaxy-s25-ultra-512gb", CategorySlug: "electronics", Brand: "Samsung", NameRU: "Galaxy S25 Ultra 512GB", NameKK: "Galaxy S25 Ultra 512GB", NameEN: "Galaxy S25 Ultra 512GB", Rating: "4.41", ReviewCount: 891, Price: "540000.00", OldPrice: "610000.00", PrimarySellerSlug: "gadgetpro", DeliveryDays: 0},
	{Slug: "pixel-10-pro-256gb", CategorySlug: "electronics", Brand: "Google", NameRU: "Pixel 10 Pro 256GB", NameKK: "Pixel 10 Pro 256GB", NameEN: "Pixel 10 Pro 256GB", Rating: "4.52", ReviewCount: 854, Price: "480000.00", OldPrice: "520000.00", PrimarySellerSlug: "techstore", DeliveryDays: 2},
	{Slug: "xiaomi-15-ultra", CategorySlug: "electronics", Brand: "Xiaomi", NameRU: "Xiaomi 15 Ultra", NameKK: "Xiaomi 15 Ultra", NameEN: "Xiaomi 15 Ultra", Rating: "4.63", ReviewCount: 817, Price: "390000.00", OldPrice: "450000.00", PrimarySellerSlug: "gadgetpro", DeliveryDays: 1},
	{Slug: "airpods-pro-3", CategorySlug: "electronics", Brand: "Apple", NameRU: "AirPods Pro 3", NameKK: "AirPods Pro 3", NameEN: "AirPods Pro 3", Rating: "4.74", ReviewCount: 780, Price: "98000.00", OldPrice: "120000.00", PrimarySellerSlug: "techstore", DeliveryDays: 0},
	{Slug: "oled-tv-65-c5", CategorySlug: "electronics", Brand: "LG", NameRU: "OLED телевизор 65\" C5", NameKK: "OLED теледидар 65\" C5", NameEN: "OLED TV 65\" C5", Rating: "4.85", ReviewCount: 743, Price: "780000.00", OldPrice: "920000.00", PrimarySellerSlug: "homecomfort", DeliveryDays: 2},
	{Slug: "qled-tv-55-neo", CategorySlug: "electronics", Brand: "Samsung", NameRU: "QLED телевизор 55\" Neo", NameKK: "QLED теледидар 55\" Neo", NameEN: "QLED TV 55\" Neo", Rating: "4.30", ReviewCount: 706, Price: "520000.00", OldPrice: "610000.00", PrimarySellerSlug: "homecomfort", DeliveryDays: 1},
	{Slug: "watch-ultra-3", CategorySlug: "electronics", Brand: "Apple", NameRU: "Watch Ultra 3", NameKK: "Watch Ultra 3", NameEN: "Watch Ultra 3", Rating: "4.41", ReviewCount: 669, Price: "260000.00", OldPrice: "290000.00", PrimarySellerSlug: "techstore", DeliveryDays: 0},
	{Slug: "sony-wh-1000xm6", CategorySlug: "electronics", Brand: "Sony", NameRU: "Наушники WH-1000XM6", NameKK: "WH-1000XM6 құлаққабы", NameEN: "WH-1000XM6 Headphones", Rating: "4.52", ReviewCount: 632, Price: "165000.00", OldPrice: "195000.00", PrimarySellerSlug: "gadgetpro", DeliveryDays: 2},

	{Slug: "macbook-pro-14-m5", CategorySlug: "computers", Brand: "Apple", NameRU: "MacBook Pro 14\" M5", NameKK: "MacBook Pro 14\" M5", NameEN: "MacBook Pro 14\" M5", Rating: "4.63", ReviewCount: 595, Price: "1150000.00", OldPrice: "1280000.00", PrimarySellerSlug: "techstore", DeliveryDays: 1},
	{Slug: "macbook-air-15-m4", CategorySlug: "computers", Brand: "Apple", NameRU: "MacBook Air 15\" M4", NameKK: "MacBook Air 15\" M4", NameEN: "MacBook Air 15\" M4", Rating: "4.74", ReviewCount: 558, Price: "780000.00", OldPrice: "850000.00", PrimarySellerSlug: "techstore", DeliveryDays: 0},
	{Slug: "rog-zephyrus-g16", CategorySlug: "computers", Brand: "Asus", NameRU: "ROG Zephyrus G16", NameKK: "ROG Zephyrus G16", NameEN: "ROG Zephyrus G16", Rating: "4.85", ReviewCount: 521, Price: "920000.00", OldPrice: "1050000.00", PrimarySellerSlug: "gadgetpro", DeliveryDays: 2},
	{Slug: "dell-xps-15-oled", CategorySlug: "computers", Brand: "Dell", NameRU: "XPS 15 OLED", NameKK: "XPS 15 OLED", NameEN: "XPS 15 OLED", Rating: "4.30", ReviewCount: 484, Price: "860000.00", OldPrice: "980000.00", PrimarySellerSlug: "gadgetpro", DeliveryDays: 1},
	{Slug: "lg-ultragear-27-240hz", CategorySlug: "computers", Brand: "LG", NameRU: "Монитор UltraGear 27\" 240Hz", NameKK: "UltraGear 27\" 240Hz мониторы", NameEN: "UltraGear 27\" 240Hz Monitor", Rating: "4.41", ReviewCount: 447, Price: "210000.00", OldPrice: "250000.00", PrimarySellerSlug: "homecomfort", DeliveryDays: 0},
	{Slug: "logitech-k10", CategorySlug: "computers", Brand: "Logitech", NameRU: "Механическая клавиатура K10", NameKK: "K10 механикалық пернетақтасы", NameEN: "K10 Mechanical Keyboard", Rating: "4.52", ReviewCount: 410, Price: "42000.00", OldPrice: "54000.00", PrimarySellerSlug: "beautylab", DeliveryDays: 2},

	{Slug: "zarina-aria-down-jacket", CategorySlug: "fashion", Brand: "Zarina", NameRU: "Пуховик премиум Aria", NameKK: "Aria сапалы пуховигі", NameEN: "Aria Premium Down Jacket", Rating: "4.63", ReviewCount: 373, Price: "68000.00", OldPrice: "98000.00", PrimarySellerSlug: "stylehub", DeliveryDays: 1},
	{Slug: "massimo-milano-jacket", CategorySlug: "fashion", Brand: "Massimo", NameRU: "Кожаная куртка Milano", NameKK: "Milano былғары куртка", NameEN: "Milano Leather Jacket", Rating: "4.74", ReviewCount: 336, Price: "145000.00", OldPrice: "185000.00", PrimarySellerSlug: "stylehub", DeliveryDays: 0},
	{Slug: "letique-noir-dress", CategorySlug: "fashion", Brand: "Letique", NameRU: "Платье вечернее Noir", NameKK: "Noir кешкі көйлегі", NameEN: "Noir Evening Dress", Rating: "4.85", ReviewCount: 299, Price: "54000.00", OldPrice: "76000.00", PrimarySellerSlug: "stylehub", DeliveryDays: 2},
	{Slug: "guess-aurora-bag", CategorySlug: "fashion", Brand: "Guess", NameRU: "Сумка кожаная Aurora", NameKK: "Aurora былғары сөмкесі", NameEN: "Aurora Leather Bag", Rating: "4.30", ReviewCount: 262, Price: "89000.00", OldPrice: "120000.00", PrimarySellerSlug: "stylehub", DeliveryDays: 1},
	{Slug: "hm-basic-hoodie", CategorySlug: "fashion", Brand: "H&M", NameRU: "Худи оверсайз Basic", NameKK: "Basic оверсайз худи", NameEN: "Basic Oversized Hoodie", Rating: "4.41", ReviewCount: 225, Price: "19500.00", OldPrice: "27000.00", PrimarySellerSlug: "stylehub", DeliveryDays: 0},

	{Slug: "nike-air-max-pulse", CategorySlug: "shoes", Brand: "Nike", NameRU: "Air Max Pulse", NameKK: "Air Max Pulse", NameEN: "Air Max Pulse", Rating: "4.52", ReviewCount: 188, Price: "62000.00", OldPrice: "78000.00", PrimarySellerSlug: "sportzone", DeliveryDays: 1},
	{Slug: "adidas-ultraboost-24", CategorySlug: "shoes", Brand: "Adidas", NameRU: "Ultraboost 24", NameKK: "Ultraboost 24", NameEN: "Ultraboost 24", Rating: "4.63", ReviewCount: 151, Price: "71000.00", OldPrice: "89000.00", PrimarySellerSlug: "sportzone", DeliveryDays: 0},
	{Slug: "ecco-oxford-shoes", CategorySlug: "shoes", Brand: "Ecco", NameRU: "Классические туфли Oxford", NameKK: "Oxford классикалық туфлиі", NameEN: "Oxford Classic Shoes", Rating: "4.74", ReviewCount: 114, Price: "58000.00", OldPrice: "74000.00", PrimarySellerSlug: "stylehub", DeliveryDays: 2},
	{Slug: "columbia-trekmax-boots", CategorySlug: "shoes", Brand: "Columbia", NameRU: "Зимние ботинки TrekMax", NameKK: "TrekMax қысқы бәтіңкесі", NameEN: "TrekMax Winter Boots", Rating: "4.85", ReviewCount: 77, Price: "47000.00", OldPrice: "63000.00", PrimarySellerSlug: "sportzone", DeliveryDays: 1},

	{Slug: "la-roche-posay-glowset", CategorySlug: "beauty", Brand: "La Roche-Posay", NameRU: "Набор для ухода GlowSet", NameKK: "GlowSet күтім жинағы", NameEN: "GlowSet Care Set", Rating: "4.30", ReviewCount: 928, Price: "32000.00", OldPrice: "41000.00", PrimarySellerSlug: "beautylab", DeliveryDays: 0},
	{Slug: "chanel-velvet-oud", CategorySlug: "beauty", Brand: "Chanel", NameRU: "Парфюм Velvet Oud 100ml", NameKK: "Velvet Oud парфюмі 100мл", NameEN: "Velvet Oud Perfume 100ml", Rating: "4.41", ReviewCount: 891, Price: "78000.00", OldPrice: "95000.00", PrimarySellerSlug: "beautylab", DeliveryDays: 2},
	{Slug: "mac-prime-palette", CategorySlug: "beauty", Brand: "MAC", NameRU: "Палетка теней Prime", NameKK: "Prime көз көлеңкесі палитрасы", NameEN: "Prime Eyeshadow Palette", Rating: "4.52", ReviewCount: 854, Price: "24500.00", OldPrice: "31000.00", PrimarySellerSlug: "beautylab", DeliveryDays: 1},

	{Slug: "ikea-loft-sofa", CategorySlug: "home", Brand: "IKEA", NameRU: "Диван модульный Loft", NameKK: "Loft модульді диваны", NameEN: "Loft Modular Sofa", Rating: "4.63", ReviewCount: 817, Price: "340000.00", OldPrice: "410000.00", PrimarySellerSlug: "homecomfort", DeliveryDays: 2},
	{Slug: "xiaomi-cleanbot-x9", CategorySlug: "home", Brand: "Xiaomi", NameRU: "Робот-пылесос CleanBot X9", NameKK: "CleanBot X9 робот-шаңсорғышы", NameEN: "CleanBot X9 Robot Vacuum", Rating: "4.74", ReviewCount: 780, Price: "145000.00", OldPrice: "180000.00", PrimarySellerSlug: "homecomfort", DeliveryDays: 1},
	{Slug: "delonghi-aromatop", CategorySlug: "home", Brand: "DeLonghi", NameRU: "Кофемашина AromaTop", NameKK: "AromaTop кофе машинасы", NameEN: "AromaTop Coffee Machine", Rating: "4.85", ReviewCount: 743, Price: "210000.00", OldPrice: "260000.00", PrimarySellerSlug: "homecomfort", DeliveryDays: 0},
	{Slug: "togas-silk-bedding", CategorySlug: "home", Brand: "Togas", NameRU: "Комплект постельного белья Silk", NameKK: "Silk төсек жабдығы жинағы", NameEN: "Silk Bedding Set", Rating: "4.30", ReviewCount: 706, Price: "38000.00", OldPrice: "49000.00", PrimarySellerSlug: "homecomfort", DeliveryDays: 2},

	{Slug: "70mai-driveeye-4k", CategorySlug: "auto", Brand: "70mai", NameRU: "Видеорегистратор DriveEye 4K", NameKK: "DriveEye 4K бейнетіркегіші", NameEN: "DriveEye 4K Dash Cam", Rating: "4.41", ReviewCount: 669, Price: "34000.00", OldPrice: "45000.00", PrimarySellerSlug: "autoplus", DeliveryDays: 1},
	{Slug: "bosch-powerair", CategorySlug: "auto", Brand: "Bosch", NameRU: "Автомобильный компрессор PowerAir", NameKK: "PowerAir авто компрессоры", NameEN: "PowerAir Car Compressor", Rating: "4.52", ReviewCount: 632, Price: "22000.00", OldPrice: "29000.00", PrimarySellerSlug: "autoplus", DeliveryDays: 0},
	{Slug: "autostyle-comfortfit", CategorySlug: "auto", Brand: "AutoStyle", NameRU: "Чехлы универсальные ComfortFit", NameKK: "ComfortFit әмбебап тыстары", NameEN: "ComfortFit Universal Seat Covers", Rating: "4.63", ReviewCount: 595, Price: "28000.00", OldPrice: "36000.00", PrimarySellerSlug: "autoplus", DeliveryDays: 2},

	{Slug: "nordictrack-prorun-t5", CategorySlug: "sport", Brand: "NordicTrack", NameRU: "Беговая дорожка ProRun T5", NameKK: "ProRun T5 жүгіру жолағы", NameEN: "ProRun T5 Treadmill", Rating: "4.74", ReviewCount: 558, Price: "480000.00", OldPrice: "580000.00", PrimarySellerSlug: "sportzone", DeliveryDays: 1},
	{Slug: "reebok-dumbbells-20kg", CategorySlug: "sport", Brand: "Reebok", NameRU: "Гантели наборные 20кг", NameKK: "20кг жиынтық гантельдер", NameEN: "20kg Adjustable Dumbbells", Rating: "4.85", ReviewCount: 521, Price: "45000.00", OldPrice: "58000.00", PrimarySellerSlug: "sportzone", DeliveryDays: 0},
	{Slug: "merida-trail-x-bike", CategorySlug: "sport", Brand: "Merida", NameRU: "Велосипед горный Trail X", NameKK: "Trail X таулы велосипеді", NameEN: "Trail X Mountain Bike", Rating: "4.30", ReviewCount: 484, Price: "320000.00", OldPrice: "380000.00", PrimarySellerSlug: "sportzone", DeliveryDays: 2},

	{Slug: "lego-galaxybricks-1200", CategorySlug: "kids", Brand: "LEGO", NameRU: "Конструктор GalaxyBricks 1200pc", NameKK: "GalaxyBricks 1200 бөлік конструкторы", NameEN: "GalaxyBricks 1200pc Building Set", Rating: "4.41", ReviewCount: 447, Price: "42000.00", OldPrice: "54000.00", PrimarySellerSlug: "kidsworld", DeliveryDays: 1},
	{Slug: "cybex-citycomfort-stroller", CategorySlug: "kids", Brand: "Cybex", NameRU: "Коляска 3в1 CityComfort", NameKK: "CityComfort 3в1 балалар арбасы", NameEN: "CityComfort 3-in-1 Stroller", Rating: "4.52", ReviewCount: 410, Price: "285000.00", OldPrice: "340000.00", PrimarySellerSlug: "kidsworld", DeliveryDays: 0},
	{Slug: "babyride-racekid", CategorySlug: "kids", Brand: "BabyRide", NameRU: "Электромобиль детский RaceKid", NameKK: "RaceKid балалар электромобилі", NameEN: "RaceKid Kids Electric Car", Rating: "4.63", ReviewCount: 373, Price: "165000.00", OldPrice: "210000.00", PrimarySellerSlug: "kidsworld", DeliveryDays: 2},
}

// reviewSnippets gives a small pool of RU review texts by rating band, used
// to generate realistic-looking (not identical) review text deterministically.
var reviewSnippets = map[int][]string{
	5: {
		"Отличный товар, полностью соответствует описанию! Рекомендую.",
		"Пользуюсь уже месяц — всё отлично, доставили быстро.",
		"Качество на высоте, обязательно закажу ещё раз.",
	},
	4: {
		"Хорошее качество за свою цену, но есть небольшие нюансы.",
		"В целом доволен покупкой, доставка немного задержалась.",
	},
	3: {
		"Товар нормальный, ожидал немного большего за эти деньги.",
	},
}

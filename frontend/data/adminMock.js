import { products } from "@/data/products";
import { sellers } from "@/data/sellers";

export function getMockUsers() {
  const names = ["Динара Ахметова", "Ерлан Смагулов", "Тимур Ким", "Расул Абенов", "Сара Ли", "Айгерим Нурланова", "Данияр Каримов"];
  return names.map((n, i) => ({
    name: n,
    email: n.split(" ")[0].toLowerCase() + "@example.com",
    orders: 3 + i * 2,
    date: `202${4 + (i % 2)}-0${(i % 9) + 1}-1${i}`,
  }));
}

export function getMockAdminOrders() {
  const statuses = ["new", "confirmed", "shipped", "delivered", "cancelled"];
  return Array.from({ length: 10 }).map((_, i) => ({
    id: `MK-2026-${20000 + i}`,
    customer: `Клиент ${i + 1}`,
    seller: sellers[i % sellers.length].name,
    total: 15000 + i * 12000,
    status: statuses[i % statuses.length],
    date: `2026-08-${10 + i}`,
  }));
}

export const adminOrderStatusLabels = { new: "Новый", confirmed: "Подтверждён", shipped: "В пути", delivered: "Доставлен", cancelled: "Отменён" };
export const adminOrderStatusClass = { new: "status-pill--new", confirmed: "status-pill--progress", shipped: "status-pill--progress", delivered: "status-pill--done", cancelled: "status-pill--cancel" };

export function getMockPayments() {
  const methods = ["Карта", "Kaspi", "Apple Pay", "Google Pay"];
  return Array.from({ length: 8 }).map((_, i) => ({
    id: `TXN-${90000 + i}`,
    method: methods[i % methods.length],
    amount: 8000 + i * 15000,
    date: `2026-08-${5 + i}`,
  }));
}

export function getMockPayouts() {
  return sellers.map((s, i) => ({
    seller: s.name,
    period: "Август 2026",
    amount: 800000 + i * 210000,
    pending: i % 3 === 0,
  }));
}

export function getMockReturns() {
  const reasons = ["Не подошёл размер", "Брак", "Передумал", "Не соответствует описанию"];
  return Array.from({ length: 6 }).map((_, i) => ({
    order: `MK-2026-${30000 + i}`,
    product: products[i * 3].title,
    reason: reasons[i % reasons.length],
    approved: i % 2 === 1,
  }));
}

export const MOCK_ADMIN_REVIEWS = [
  { name: "Мадина Т.", text: "Отличный сервис и быстрая доставка по всей стране.", rating: 5 },
  { name: "Асхат Б.", text: "Товар пришёл с задержкой, но поддержка быстро помогла.", rating: 4 },
];

export const GMV_BY_MONTH = [
  { label: "Мар", value: 340 }, { label: "Апр", value: 365 }, { label: "Май", value: 390 },
  { label: "Июн", value: 410 }, { label: "Июл", value: 445 }, { label: "Авг", value: 482 },
];

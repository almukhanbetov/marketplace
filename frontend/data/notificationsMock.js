export const mockNotifications = [
  { id: 1, icon: "🚚", key: "order_shipped", unread: true, time: "5 мин назад" },
  { id: 2, icon: "💸", key: "price_drop", unread: true, time: "2 ч назад" },
  { id: 3, icon: "💬", key: "seller_reply", unread: true, time: "вчера" },
  { id: 4, icon: "↩️", key: "return_approved", unread: false, time: "2 дня назад" },
];

export const notifTexts = {
  ru: {
    order_shipped: "Ваш заказ передан в доставку",
    price_drop: "Цена товара снизилась",
    seller_reply: "Продавец ответил на ваш вопрос",
    return_approved: "Возврат одобрен",
  },
  kk: {
    order_shipped: "Тапсырысыңыз жеткізуге берілді",
    price_drop: "Тауар бағасы төмендеді",
    seller_reply: "Сатушы сұрағыңызға жауап берді",
    return_approved: "Қайтару мақұлданды",
  },
  en: {
    order_shipped: "Your order is out for delivery",
    price_drop: "Price dropped on a saved item",
    seller_reply: "Seller replied to your question",
    return_approved: "Return approved",
  },
};

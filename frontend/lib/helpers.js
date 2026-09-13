export function deliveryLabel(code, t, lang) {
  if (code === "tomorrow") return t("deliveryTomorrow");
  if (code === "today") return t("deliveryToday");
  return t("delivery") + ": 2 " + (lang === "en" ? "days" : "дня");
}

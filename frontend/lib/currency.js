export function formatPrice(value) {
  const n = typeof value === "string" ? Number(value) : value;
  if (!Number.isFinite(n)) return "";
  // ru-RU already uses a non-breaking space for thousands, so the only
  // comma toLocaleString can produce is the decimal separator — blindly
  // replacing every comma with a space (the old implementation) corrupted
  // it into a run of digits (e.g. "398 783,52" -> "398 783 52"). Rounding
  // to a whole number, consistent with how every other amount in this app
  // is displayed, sidesteps that entirely.
  return Math.round(n).toLocaleString("ru-RU") + " ₸";
}

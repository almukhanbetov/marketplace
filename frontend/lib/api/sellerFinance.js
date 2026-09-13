import { apiFetch } from "@/lib/api/client";

export async function getSellerFinance() {
  const res = await apiFetch("/seller/finance");
  return res.data;
}

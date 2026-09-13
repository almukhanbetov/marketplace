import { apiFetch } from "@/lib/api/client";

export async function getSellerDashboard() {
  const res = await apiFetch("/seller/dashboard");
  return res.data;
}

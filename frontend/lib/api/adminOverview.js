import { apiFetch } from "@/lib/api/client";

export async function getAdminOverview() {
  const res = await apiFetch("/admin/overview");
  return res.data;
}

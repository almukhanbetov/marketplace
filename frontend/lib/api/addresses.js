import { apiFetch } from "@/lib/api/client";

export async function getAddresses() {
  const res = await apiFetch("/me/addresses");
  return res.data ?? [];
}

export async function createAddress(input) {
  const res = await apiFetch("/me/addresses", { method: "POST", body: JSON.stringify(input) });
  return res.data;
}

export async function updateAddress(addressId, input) {
  const res = await apiFetch(`/me/addresses/${addressId}`, { method: "PUT", body: JSON.stringify(input) });
  return res.data;
}

export async function setDefaultAddress(addressId) {
  const res = await apiFetch(`/me/addresses/${addressId}/default`, { method: "PATCH" });
  return res.data;
}

export async function deleteAddress(addressId) {
  await apiFetch(`/me/addresses/${addressId}`, { method: "DELETE" });
}

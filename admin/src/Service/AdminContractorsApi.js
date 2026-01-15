import adminApi from "./adminApi";

const ADMIN = "/api/admin";

// GET /api/admin/contractors/pending
export async function adminGetPendingContractors() {
  const res = await adminApi.get(`${ADMIN}/contractors/pending`);
  return res.data; // array
}

// PATCH /api/admin/contractors/:id/status
// body: { status: "verified" | "rejected" }
export async function adminUpdateContractorStatus(id, payload) {
  const res = await adminApi.patch(`${ADMIN}/contractors/${id}/status`, payload);
  return res.data; // { message, contractor }
}

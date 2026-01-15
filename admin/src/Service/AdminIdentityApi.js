import adminApi from "./adminApi";

const ADMIN = "/api/admin";

// GET /api/admin/users/pending-identity
export async function adminGetPendingIdentities() {
  const res = await adminApi.get(`${ADMIN}/users/pending-identity`);
  return res.data; // array
}

// GET /api/admin/users/:role/:id/identity
export async function adminGetIdentityDetails(role, id) {
  const res = await adminApi.get(`${ADMIN}/users/${role}/${id}/identity`);
  return res.data; // user object with urls
}

// PATCH /api/admin/users/:role/:id/identity-status
// body: { status: "verified"|"rejected", nationalId?: "..." }
export async function adminUpdateIdentityStatus(role, id, payload) {
  const res = await adminApi.patch(
    `${ADMIN}/users/${role}/${id}/identity-status`,
    payload
  );
  return res.data; // { message, user }
}

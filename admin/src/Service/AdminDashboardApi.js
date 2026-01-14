import adminApi from "./adminApi";

const ADMIN = "/api/admin";

// ✅ 1) إحضار كل المستخدمين (اختياري role)
export async function adminGetUsers(role) {
  const res = await adminApi.get(`${ADMIN}/users`, {
    params: role ? { role } : undefined,
  });
  return res.data; // array
}

// ✅ 2) إحضار pending identities
export async function adminGetPendingIdentities() {
  const res = await adminApi.get(`${ADMIN}/users/pending-identity`);
  return res.data; // array
}

// ✅ 3) إحضار pending contractors
export async function adminGetPendingContractors() {
  const res = await adminApi.get(`${ADMIN}/contractors/pending`);
  return res.data; // array
}

// ✅ 4) إحضار مستخدم حسب role + id
export async function adminGetUserById(role, id) {
  if (!role || !id) {
    throw new Error("role and id are required");
  }
  const res = await adminApi.get(`${ADMIN}/users/${role}/${id}`);
  return res.data;
}

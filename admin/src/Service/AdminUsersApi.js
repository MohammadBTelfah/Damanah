import adminApi from "./adminApi";

const ADMIN = "/api/admin";

// GET /api/admin/users?role=client|contractor|admin (optional)
export async function adminGetUsers(role) {
  const res = await adminApi.get(`${ADMIN}/users`, {
    params: role ? { role } : undefined,
  });
  return res.data; // array
}

// PATCH /api/admin/users/:role/:id
export async function adminUpdateUser(role, id, updates) {
  const res = await adminApi.patch(
    `${ADMIN}/users/${role}/${id}`,
    updates
  );
  return res.data; // { message, user }
}

// DELETE /api/admin/users/:role/:id
export async function adminDeleteUser(role, id) {
  const res = await adminApi.delete(
    `${ADMIN}/users/${role}/${id}`
  );
  return res.data; // { message }
}

// PATCH /api/admin/users/:role/:id/toggle-active
export async function adminToggleUserActive(role, id) {
  const res = await adminApi.patch(
    `${ADMIN}/users/${role}/${id}/toggle-active`
  );
  return res.data; // { message, user }
}

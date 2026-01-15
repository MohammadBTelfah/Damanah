import adminApi from "./adminApi";

const ADMIN_ACCOUNT = "/api/admin/account";

// GET /api/admin/account/me
export async function adminGetMe() {
  const res = await adminApi.get(`${ADMIN_ACCOUNT}/me`);
  return res.data;
}

// PUT /api/admin/account/me
// multipart/form-data
export async function adminUpdateMe({ name, phone, profileImageFile }) {
  const fd = new FormData();
  if (name !== undefined) fd.append("name", name);
  if (phone !== undefined) fd.append("phone", phone);
  if (profileImageFile) fd.append("profileImage", profileImageFile);

  const res = await adminApi.put(`${ADMIN_ACCOUNT}/me`, fd);
  return res.data;
}

// PUT /api/admin/account/change-password
export async function adminChangePassword({ currentPassword, newPassword }) {
  const res = await adminApi.put(
    `${ADMIN_ACCOUNT}/change-password`,
    { currentPassword, newPassword }
  );
  return res.data;
}

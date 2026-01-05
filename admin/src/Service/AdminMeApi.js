import axios from "axios";

const API_BASE = process.env.REACT_APP_API_BASE_URL || "http://localhost:5000";
const ADMIN_ACCOUNT = `${API_BASE}/api/admin/account`;
const SESSION_KEY = "admin_session";

function getToken() {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
        console.log("admin_session raw:", raw); // ✅ للتأكد

    if (!raw) return null;
    const s = JSON.parse(raw);
    return s?.token || null;
  } catch {
    return null;
  }
}

function authHeaders() {
  const token = getToken();
  return token ? { Authorization: `Bearer ${token}` } : {};
}

export async function adminGetMe() {
  const res = await axios.get(`${ADMIN_ACCOUNT}/me`, {
    headers: authHeaders(),
  });
  return res.data;
}

export async function adminUpdateMe({ name, phone, profileImageFile }) {
  const fd = new FormData();
  if (name !== undefined) fd.append("name", name);
  if (phone !== undefined) fd.append("phone", phone);
  if (profileImageFile) fd.append("profileImage", profileImageFile);

  const res = await axios.put(`${ADMIN_ACCOUNT}/me`, fd, {
    headers: authHeaders(),
  });
  return res.data;
}

export async function adminChangePassword({ currentPassword, newPassword }) {
  const res = await axios.put(
    `${ADMIN_ACCOUNT}/change-password`,
    { currentPassword, newPassword },
    { headers: authHeaders() }
  );
  return res.data;
}

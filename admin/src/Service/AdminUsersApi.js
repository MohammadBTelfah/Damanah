import axios from "axios";

const API_BASE = process.env.REACT_APP_API_BASE_URL || "http://localhost:5000";
const ADMIN = `${API_BASE}/api/admin`;
const SESSION_KEY = "admin_session";

function getToken() {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
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

// GET /api/admin/users?role=client|contractor|admin (optional)
export async function adminGetUsers(role) {
  const url = role ? `${ADMIN}/users?role=${role}` : `${ADMIN}/users`;
  const res = await axios.get(url, { headers: authHeaders() });
  return res.data; // array
}

// PATCH /api/admin/users/:role/:id
export async function adminUpdateUser(role, id, updates) {
  const res = await axios.patch(`${ADMIN}/users/${role}/${id}`, updates, {
    headers: authHeaders(),
  });
  return res.data; // { message, user }
}

// DELETE /api/admin/users/:role/:id
export async function adminDeleteUser(role, id) {
  const res = await axios.delete(`${ADMIN}/users/${role}/${id}`, {
    headers: authHeaders(),
  });
  return res.data; // { message }
}

// PATCH /api/admin/users/:role/:id/toggle-active
export async function adminToggleUserActive(role, id) {
  const res = await axios.patch(`${ADMIN}/users/${role}/${id}/toggle-active`, null, {
    headers: authHeaders(),
  });
  return res.data; // { message, user }
}

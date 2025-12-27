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

// GET /api/admin/users/pending-identity
export async function adminGetPendingIdentities() {
  const res = await axios.get(`${ADMIN}/users/pending-identity`, {
    headers: authHeaders(),
  });
  return res.data; // array
}

// GET /api/admin/users/:role/:id/identity
export async function adminGetIdentityDetails(role, id) {
  const res = await axios.get(`${ADMIN}/users/${role}/${id}/identity`, {
    headers: authHeaders(),
  });
  return res.data; // user object with urls
}

// PATCH /api/admin/users/:role/:id/identity-status
// body: { status: "verified"|"rejected", nationalId?: "..." }
export async function adminUpdateIdentityStatus(role, id, payload) {
  const res = await axios.patch(`${ADMIN}/users/${role}/${id}/identity-status`, payload, {
    headers: authHeaders(),
  });
  return res.data; // { message, user }
}

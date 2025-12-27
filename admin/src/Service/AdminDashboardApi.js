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

// ✅ 1) إحضار كل المستخدمين (اختياري role)
export async function adminGetUsers(role) {
  const res = await axios.get(`${ADMIN}/users`, {
    headers: authHeaders(),
    params: role ? { role } : undefined,
  });
  return res.data; // array
}

// ✅ 2) إحضار pending identities
export async function adminGetPendingIdentities() {
  const res = await axios.get(`${ADMIN}/users/pending-identity`, {
    headers: authHeaders(),
  });
  return res.data; // array
}

// ✅ 3) إحضار pending contractors
export async function adminGetPendingContractors() {
  const res = await axios.get(`${ADMIN}/contractors/pending`, {
    headers: authHeaders(),
  });
  return res.data; // array
}

// ✅ 4) (مهم) get user by id — لازم role + id سترينغ
export async function adminGetUserById(role, id) {
  if (!role || !id) throw new Error("role and id are required");
  const res = await axios.get(`${ADMIN}/users/${role}/${id}`, {
    headers: authHeaders(),
  });
  return res.data;
}

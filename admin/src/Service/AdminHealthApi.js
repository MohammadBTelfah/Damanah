import axios from "axios";

const API_BASE = process.env.REACT_APP_API_BASE_URL || "http://localhost:5000";
const SESSION_KEY = "admin_session";

function getToken() {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    return JSON.parse(raw)?.token || null;
  } catch {
    return null;
  }
}

export async function checkAuthHealth() {
  const res = await axios.get(`${API_BASE}/api/health/auth`, { timeout: 6000 });
  return res.data;
}

export async function checkAdminApisHealth() {
  const token = getToken();
  const res = await axios.get(`${API_BASE}/api/admin/account/ping`, {
    timeout: 6000,
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  return res.data;
}

export async function checkUploadsHealth() {
  // أبسط فحص: تأكد إن static شغال
  const res = await axios.get(`${API_BASE}/api/health/uploads`, { timeout: 6000 });
  return res.data;
}

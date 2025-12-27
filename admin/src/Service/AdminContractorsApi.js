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

// GET /api/admin/contractors/pending
export async function adminGetPendingContractors() {
  const res = await axios.get(`${ADMIN}/contractors/pending`, {
    headers: authHeaders(),
  });
  return res.data; // array
}

// PATCH /api/admin/contractors/:id/status
// body: { status: "verified" | "rejected" }
export async function adminUpdateContractorStatus(id, payload) {
  const res = await axios.patch(`${ADMIN}/contractors/${id}/status`, payload, {
    headers: authHeaders(),
  });
  return res.data; // { message, contractor }
}

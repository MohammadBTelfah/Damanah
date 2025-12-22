import axios from "axios";

const API_BASE = process.env.REACT_APP_API_BASE_URL || "http://localhost:5000";
const ADMIN_AUTH = `${API_BASE}/api/auth/admin`;

export async function adminRegister(formData, adminSecret) {
  const res = await axios.post(`${ADMIN_AUTH}/register`, formData, {
    headers: {
      "x-admin-secret": adminSecret,
      // لا تكتب Content-Type بنفسك؛ axios رح يضبطه مع boundary
    },
  });
  return res.data;
}


export async function adminLogin(payload) {
  const res = await axios.post(`${ADMIN_AUTH}/login`, payload);
  return res.data;
}

export async function adminVerifyEmail(token) {
  const res = await axios.get(`${ADMIN_AUTH}/verify-email/${token}`);
  return res.data;
}


export async function adminResendVerification(payload) {
  const res = await axios.post(`${ADMIN_AUTH}/resend-verification`, payload);
  return res.data;
}

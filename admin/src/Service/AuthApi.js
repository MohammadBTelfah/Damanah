import axios from "axios";
import adminApi from "./adminApi"; // ✅ عشان نحدّث الهيدر بعد login

const API_BASE = process.env.REACT_APP_API_BASE_URL || "http://localhost:5000";
const ADMIN_AUTH = `${API_BASE}/api/auth/admin`;

// ✅ مفتاح واحد فقط بكل المشروع
export const ADMIN_SESSION_KEY = "adminSession";

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
  const data = res.data;

  // ✅ إذا السيرفر رجّع توكن: خزّنه فوراً + حدّث adminApi
  const token = data?.token || data?.accessToken || data?.jwt;
  const admin = data?.admin || data?.user || null;

  if (token) {
    const session = { token, admin };
    localStorage.setItem(ADMIN_SESSION_KEY, JSON.stringify(session));
    localStorage.removeItem("admin_session"); // ✅ تنظيف القديم

    // ✅ مهم: أول request بعد login يكون معه توكن بدون refresh
    adminApi.defaults.headers.common.Authorization = `Bearer ${token}`;
  }

  return data;
}

export async function adminVerifyEmail(token) {
  const res = await axios.get(`${ADMIN_AUTH}/verify-email/${token}`);
  return res.data;
}

export async function adminResendVerification(payload) {
  const res = await axios.post(`${ADMIN_AUTH}/resend-verification`, payload);
  return res.data;
}

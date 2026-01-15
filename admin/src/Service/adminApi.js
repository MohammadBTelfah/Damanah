import axios from "axios";

const API_BASE =
  process.env.REACT_APP_API_BASE_URL || "http://localhost:5000";

const adminApi = axios.create({
  baseURL: API_BASE,
});

// ✅ اقرأ التوكن بكل request (مش مرة وحدة)
adminApi.interceptors.request.use((config) => {
  const raw = localStorage.getItem("adminSession"); // ✅ مفتاح واحد فقط
  if (raw) {
    try {
      const session = JSON.parse(raw);
      const token = session?.token;
      if (token) config.headers.Authorization = `Bearer ${token}`;
    } catch (_) {}
  }
  return config;
});

export default adminApi;
export { API_BASE };

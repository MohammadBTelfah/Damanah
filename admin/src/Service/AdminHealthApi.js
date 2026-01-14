import adminApi from "./adminApi";

// ✅ Auth health
export async function checkAuthHealth() {
  const res = await adminApi.get("/api/health/auth", { timeout: 6000 });
  return res.data;
}

// ✅ Admin APIs health (public health endpoint)
export async function checkAdminApisHealth() {
  const res = await adminApi.get("/api/health/admin", { timeout: 6000 });
  return res.data;
}

// ✅ Uploads health
export async function checkUploadsHealth() {
  const res = await adminApi.get("/api/health/uploads", { timeout: 6000 });
  return res.data;
}

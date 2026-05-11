const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const dotenv = require("dotenv");

dotenv.config();

const app = express();

// ============================================================
// 🔴 (1) التعديل الحاسم: إعداد مجلد الصور في البداية
// ============================================================

// نستخدم __dirname لأن مجلد uploads موجود بجانب ملف index.js مباشرة

// ============================================================
// 🟢 (2) باقي الـ Middlewares تأتي بعد الصور
// ============================================================

app.use(cors({
  origin: ['https://damanah-admin.vercel.app', 'http://localhost:3000'], // ضع رابط Vercel هنا
  credentials: true
}));
app.use(express.json());

// Routes imports
const ClientAuthRoutes = require("./routes/Auth/clientAuthRoutes");
const ContractorAuthRoutes = require("./routes/Auth/contractorAuthRoutes");
const AdminAuthRoutes = require("./routes/Auth/adminAuthRoutes");
const adminRoutes = require("./routes/admin/adminRoutes");
const projectRoutes = require("./routes/projectRoutes");
const contractorAccountRoutes = require("./routes/contractor/accountRoutes");
const clientAccountRoutes = require("./routes/client/accountRoutes");
const adminAccountRoutes = require("./routes/admin/accountRoutes");
const healthRoutes = require("./routes/healthRoutes");
const materialRoutes = require("./routes/materialRoutes");
const notificationRoutes = require("./routes/notificationRoutes");
const publicRoutes = require("./routes/publicRoutes");
const tipRoutes = require("./routes/tipRoutes");
const contractRoutes = require("./routes/contractRoutes");

app.get("/", (req, res) => {
  res.json({ message: "Damanah API is running 🚀" });
});

// API routes
app.use("/api/health", healthRoutes);

app.use("/api/auth/client", ClientAuthRoutes);
app.use("/api/auth/contractor", ContractorAuthRoutes);
app.use("/api/auth/admin", AdminAuthRoutes);

// الترتيب: المحدد قبل العام
app.use("/api/admin/account", adminAccountRoutes);
app.use("/api/admin", adminRoutes);

app.use("/api/projects", projectRoutes);
app.use("/api/contractor/account", contractorAccountRoutes);
app.use("/api/client/account", clientAccountRoutes);
app.use("/api/materials", materialRoutes);

app.use("/api/notifications", notificationRoutes);
app.use("/api/public", publicRoutes);
app.use("/api/tips", tipRoutes);
app.use("/api/contracts", contractRoutes);

// MongoDB connection
const PORT = process.env.PORT || 5000;
const HOST = "0.0.0.0";
const MONGO_URI = process.env.MONGO_URI;

app.listen(PORT, HOST, () => {
  console.log(`🚀 Server running on http://${HOST}:${PORT}`);
});

mongoose
  .connect(MONGO_URI)
  .then(() => {
    console.log("✅ MongoDB Connected");
  })
  .catch((err) => {
    console.error("❌ MongoDB connection error:", err.message);
  });
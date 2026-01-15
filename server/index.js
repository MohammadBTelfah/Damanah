const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const dotenv = require("dotenv");
const path = require("path");
dotenv.config();
const fs = require("fs");

const app = express();

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

// Middlewares
app.use(cors());
app.use(express.json());

// 🔥 مهم جداً: عرض ملفّات الرفع

const UPLOADS_DIR = path.join(__dirname, "uploads");

app.use("/uploads", express.static(UPLOADS_DIR));

// Test route
app.get("/", (req, res) => {
  res.json({ message: "Damanah API is running 🚀" });
});

// API routes

app.use("/api/health", healthRoutes);

app.use("/api/auth/client", ClientAuthRoutes);
app.use("/api/auth/contractor", ContractorAuthRoutes);
app.use("/api/auth/admin", AdminAuthRoutes);

// ✅ خلي الراوت الأكثر تحديدًا قبل العام (حل 404)
app.use("/api/admin/account", adminAccountRoutes);
app.use("/api/admin", adminRoutes);

app.use("/api/projects", projectRoutes);
app.use("/api/contractor/account", contractorAccountRoutes);
app.use("/api/client/account", clientAccountRoutes);
app.use("/api/materials", materialRoutes);

// MongoDB connection
const PORT = process.env.PORT || 5000;
const MONGO_URI = process.env.MONGO_URI;

mongoose
  .connect(MONGO_URI)
  .then(() => {
    console.log("✅ MongoDB Connected");
    const HOST = "0.0.0.0";

    app.listen(PORT, HOST, () => {
      console.log(`🚀 Server running on http://${HOST}:${PORT}`);
    });
  })
  .catch((err) => {
    console.error("❌ MongoDB connection error:", err.message);
  });

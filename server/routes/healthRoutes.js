const router = require("express").Router();

// عام: السيرفر شغال
router.get("/", (req, res) => {
  res.json({ ok: true, service: "api", ts: Date.now() });
});

// Auth: افحص إن auth routes موجودة (مثلاً ping بسيط)
router.get("/auth", (req, res) => {
  res.json({ ok: true, service: "auth", ts: Date.now() });
});

// Admin APIs: افحص admin routes (ممكن تخليه protected لو بدك)
router.get("/admin", (req, res) => {
  res.json({ ok: true, service: "admin", ts: Date.now() });
});

// Uploads: افحص إن static uploads شغال (بس check بسيط)
router.get("/uploads", (req, res) => {
  res.json({ ok: true, service: "uploads", ts: Date.now() });
});

module.exports = router;

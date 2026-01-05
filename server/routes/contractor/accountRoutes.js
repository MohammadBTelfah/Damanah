const router = require("express").Router();
const me = require("../../controllers/meController");
const {
  protect,
  contractorOnly,
  verifiedAndActive,
} = require("../../middleware/authMiddleWare");
const {
  forgotPasswordLimiter,
  resetPasswordLimiter,
} = require("../../middleware/rateLimiters");

const multer = require("multer");
const path = require("path");
const fs = require("fs");

// ✅ FIX: اطلع مرتين لفوق عشان توصل لـ server/uploads
const UPLOADS_DIR = path.join(__dirname, "..", "..", "uploads");
const PROFILES_DIR = path.join(UPLOADS_DIR, "profiles");

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

ensureDir(PROFILES_DIR);

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, PROFILES_DIR);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || ".jpg";
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
  },
});

function fileFilter(req, file, cb) {
  const mimeOk = file.mimetype && file.mimetype.startsWith("image/");
  const ext = path.extname(file.originalname || "").toLowerCase();
  const extOk = [".jpg", ".jpeg", ".png", ".webp", ".heic"].includes(ext);

  if (mimeOk || extOk) return cb(null, true);
  cb(new Error("profileImage must be an image"), false);
}

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
});

router.get("/me", protect, contractorOnly, verifiedAndActive, me.getMe);

router.put(
  "/me",
  protect,
  contractorOnly,
  verifiedAndActive,
  upload.single("profileImage"),
  me.updateMe
);

router.delete("/me", protect, contractorOnly, verifiedAndActive, me.deleteMe);

router.put(
  "/change-password",
  protect,
  contractorOnly,
  verifiedAndActive,
  me.changePassword
);

router.post("/forgot-password", forgotPasswordLimiter, me.forgotPassword);
router.post("/reset-password", resetPasswordLimiter, me.resetPassword);

module.exports = router;

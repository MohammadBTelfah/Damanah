const router = require("express").Router();
const me = require("../../controllers/meController");
const { forgotPasswordLimiter, resetPasswordLimiter } = require("../../middleware/rateLimiters");

const { protect, adminOnly, verifiedAndActive } = require("../../middleware/authMiddleWare");

const multer = require("multer");
const path = require("path");
const fs = require("fs");

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadPath = path.join(process.cwd(), "uploads", "profiles");
    ensureDir(uploadPath);
    cb(null, uploadPath);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
  },
});

function fileFilter(req, file, cb) {
  if (file.mimetype.startsWith("image/")) return cb(null, true);
  cb(new Error("profileImage must be an image"), false);
}

const upload = multer({ storage, fileFilter });

// ✅ CRUD for own account
router.get("/ping", (req, res) => res.json({ ok: true })); // ✅ test

router.get("/me", protect, adminOnly, verifiedAndActive, me.getMe);
router.put("/me", protect, adminOnly, verifiedAndActive, upload.single("profileImage"), me.updateMe);
router.delete("/me", protect, adminOnly, verifiedAndActive, me.deleteMe);

// ✅ change password
router.put("/change-password", protect, adminOnly, verifiedAndActive, me.changePassword);
router.post("/forgot-password", forgotPasswordLimiter, me.forgotPassword);
router.post("/reset-password", resetPasswordLimiter, me.resetPassword);

module.exports = router;

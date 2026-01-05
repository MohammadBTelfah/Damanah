const router = require("express").Router();
const me = require("../../controllers/meController");
const { protect, contractorOnly, verifiedAndActive } = require("../../middleware/authMiddleWare");
const { forgotPasswordLimiter, resetPasswordLimiter } = require("../../middleware/rateLimiters");

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

router.get("/me", protect, contractorOnly, verifiedAndActive, me.getMe);
router.put("/me", protect, contractorOnly, verifiedAndActive, upload.single("profileImage"), me.updateMe);
router.delete("/me", protect, contractorOnly, verifiedAndActive, me.deleteMe);

router.put("/change-password", protect, contractorOnly, verifiedAndActive, me.changePassword);
router.post("/forgot-password", forgotPasswordLimiter, me.forgotPassword);
router.post("/reset-password", resetPasswordLimiter, me.resetPassword);

module.exports = router;

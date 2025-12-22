const router = require("express").Router();
const adminAuth = require("../../controllers/Auth/adminauthcontroller");
const multer = require("multer");
const path = require("path");
const fs = require("fs");

/* ================== UPLOAD SETUP ================== */
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

/* ================== ROUTES (NO AUTH) ================== */
router.post("/register", upload.single("profileImage"), adminAuth.register);
router.post("/login", adminAuth.login);

// email verification
router.get("/verify-email/:token", adminAuth.verifyEmail);
router.post("/resend-verification", adminAuth.resendVerificationEmail);

module.exports = router;

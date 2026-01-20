const router = require("express").Router();
const adminAuth = require("../../controllers/Auth/adminauthcontroller");

// ✅ NEW: استدعاء إعدادات Cloudinary بدلاً من الـ Multer المحلي
const upload = require("../../utils/upload");

/* ================== ROUTES (NO AUTH) ================== */

// الآن سيتم رفع الصورة إلى Cloudinary تلقائياً عند التسجيل
router.post("/register", upload.single("profileImage"), adminAuth.register);

router.post("/login", adminAuth.login);

// email verification
router.get("/verify-email/:token", adminAuth.verifyEmail);
router.post("/resend-verification", adminAuth.resendVerificationEmail);

module.exports = router;
const router = require("express").Router();
const adminAuth = require("../../controllers/Auth/adminauthcontroller");

// ✅ NEW: استدعاء إعدادات Cloudinary بدلاً من الـ Multer المحلي
const { uploadProfileImage } = require("../../utils/upload");
/* ================== ROUTES (NO AUTH) ================== */

router.post("/register", uploadProfileImage.single("profileImage"), adminAuth.register);
router.post("/login", adminAuth.login);

// email verification
router.get("/verify-email/:token", adminAuth.verifyEmail);
router.post("/resend-verification", adminAuth.resendVerificationEmail);

module.exports = router;
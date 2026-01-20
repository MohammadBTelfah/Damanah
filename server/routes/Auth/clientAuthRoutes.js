const router = require("express").Router();
const clientAuth = require("../../controllers/Auth/clientauthcontroller");

// ✅ التعديل 1: استدعاء الأداة المحددة بدلاً من الملف كاملاً
// نستخدم الأقواس {} لأننا نريد أداة محددة من الملف
const { uploadIdentityDoc } = require("../../utils/upload");

/* ================== ROUTES (NO AUTH) ================== */

// register
router.post(
  "/register",
  // ✅ التعديل 2: استخدام uploadIdentityDoc بدلاً من upload
  uploadIdentityDoc.fields([
    { name: "profileImage", maxCount: 1 },
    { name: "identityDocument", maxCount: 1 },
  ]),
  clientAuth.register
);

// login
router.post("/login", clientAuth.login);

// ✅ email verification
router.get("/verify-email/:token", clientAuth.verifyEmail);

// ✅ resend verification email
router.post("/resend-verification", clientAuth.resendVerificationEmail);

module.exports = router;
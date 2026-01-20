const router = require("express").Router();
const clientAuth = require("../../controllers/Auth/clientauthcontroller");

// ✅ NEW: استدعاء إعدادات Cloudinary الجاهزة
const upload = require("../../utils/upload");

/* ================== ROUTES (NO AUTH) ================== */

// register
router.post(
  "/register",
  // Cloudinary Config يدعم upload.fields تماماً كما هو
  upload.fields([
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
const router = require("express").Router();
const contractorAuth = require("../../controllers/Auth/contractorAuthcontroller");

// ✅ NEW: استيراد إعدادات Cloudinary
const upload = require("../../utils/upload");

/* ================== ROUTES (NO AUTH) ================== */

// register
router.post(
  "/register",
  // Cloudinary Config يدعم upload.fields تماماً
  upload.fields([
    { name: "profileImage", maxCount: 1 },
    { name: "identityDocument", maxCount: 1 },
    { name: "contractorDocument", maxCount: 1 },
  ]),
  contractorAuth.register
);

// login
router.post("/login", contractorAuth.login);

// ✅ email verification
router.get("/verify-email/:token", contractorAuth.verifyEmail);

// ✅ resend verification email
router.post("/resend-verification", contractorAuth.resendVerificationEmail);

module.exports = router;
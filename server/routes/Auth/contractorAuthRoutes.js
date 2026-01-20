const router = require("express").Router();
const contractorAuth = require("../../controllers/Auth/contractorAuthcontroller");

// ✅ التعديل 1: استدعاء الأداة المناسبة (uploadContractorDoc)
// نستخدم الأقواس {} لأننا نستدعي أداة محددة من الملف
const { uploadContractorDoc } = require("../../utils/upload");

/* ================== ROUTES (NO AUTH) ================== */

// register
router.post(
  "/register",
  // ✅ التعديل 2: استخدام uploadContractorDoc بدلاً من upload
  // هذه الأداة مهيأة لقبول الصور والملفات (PDF) معاً
  uploadContractorDoc.fields([
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
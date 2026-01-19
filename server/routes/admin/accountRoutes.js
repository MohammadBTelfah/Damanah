const router = require("express").Router();
const me = require("../../controllers/meController");
const {
  protect,
  contractorOnly,
  verifiedAndActive,
  adminOnly
} = require("../../middleware/authMiddleWare");
const {
  forgotPasswordLimiter,
  resetPasswordLimiter,
} = require("../../middleware/rateLimiters");

// ✅ NEW: استيراد إعدادات Cloudinary بدلاً من الكود المحلي
const upload = require("../../config/cloudinaryConfig");

router.get("/me", protect, adminOnly, verifiedAndActive, me.getMe);

router.put(
  "/me",
  protect,
  adminOnly,
  verifiedAndActive,
  upload.single("profileImage"), // سيتم الرفع الآن إلى Cloudinary مباشرة
  me.updateMe
);

router.delete("/me", protect, adminOnly, verifiedAndActive, me.deleteMe);

router.put(
  "/change-password",
  protect,
  adminOnly,
  verifiedAndActive,
  me.changePassword
);

router.post("/forgot-password", forgotPasswordLimiter, me.forgotPassword);
router.post("/reset-password", resetPasswordLimiter, me.resetPassword);

module.exports = router;
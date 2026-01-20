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

// ✅ التعديل 1: استدعاء uploadProfileImage
const { uploadProfileImage } = require("../../utils/upload");

router.get("/me", protect, adminOnly, verifiedAndActive, me.getMe);

router.put(
  "/me",
  protect,
  adminOnly,
  verifiedAndActive,
  // ✅ التعديل 2: استخدام uploadProfileImage بدلاً من upload
  uploadProfileImage.single("profileImage"), 
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
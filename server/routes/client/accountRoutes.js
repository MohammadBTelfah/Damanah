const router = require("express").Router();
const me = require("../../controllers/meController");
const {
  protect,
  contractorOnly,
  verifiedAndActive,
  clientOnly,
} = require("../../middleware/authMiddleWare");
const {
  forgotPasswordLimiter,
  resetPasswordLimiter,
} = require("../../middleware/rateLimiters");

// ✅ التعديل 1: استدعاء uploadProfileImage
const { uploadProfileImage } = require("../../utils/upload");

router.get("/me", protect, clientOnly, verifiedAndActive, me.getMe);

router.put(
  "/me",
  protect,
  clientOnly,
  verifiedAndActive,
  // ✅ التعديل 2: استخدام uploadProfileImage بدلاً من upload
  uploadProfileImage.single("profileImage"), 
  me.updateMe
);

router.delete("/me", protect, clientOnly, verifiedAndActive, me.deleteMe);

router.put(
  "/change-password",
  protect,
  clientOnly,
  verifiedAndActive,
  me.changePassword
);

router.post("/forgot-password", forgotPasswordLimiter, me.forgotPassword);
router.post("/reset-password", resetPasswordLimiter, me.resetPassword);

module.exports = router;
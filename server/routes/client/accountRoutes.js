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

// ✅ NEW: استبدال كود الرفع المحلي بـ Cloudinary
const upload = require("../../utils/upload");

router.get("/me", protect, clientOnly, verifiedAndActive, me.getMe);

router.put(
  "/me",
  protect,
  clientOnly,
  verifiedAndActive,
  upload.single("profileImage"), // الرفع سيتم على Cloudinary مباشرة
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
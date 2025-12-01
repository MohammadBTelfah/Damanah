const express = require("express");
const router = express.Router();
const {
  getProfile,
  updateProfile,
  deleteMyAccount,
  changePassword,
  requestPasswordReset,
  resetPassword,
} = require("../controllers/userController");
const { protect } = require("../middleware/authMiddleWare");

// تحتاج تسجيل دخول
router.get("/me", protect, getProfile);
router.patch("/me", protect, updateProfile);
router.delete("/me", protect, deleteMyAccount);
router.patch("/change-password", protect, changePassword);

// نسيان كلمة المرور
router.post("/request-password-reset", requestPasswordReset);
router.post("/reset-password", resetPassword);

module.exports = router;

const express = require("express");
const router = express.Router();
const {
  getAllUsers,
  getUserById,
  updateUserByAdmin,
  deleteUserByAdmin,
  toggleUserActiveStatus,
  getPendingIdentities,
  updateIdentityStatus,
  getPendingContractors,
  updateContractorStatus,
} = require("../controllers/adminController");
const { protect, adminOnly } = require("../middleware/authMiddleWare");

// كل مسارات الأدمن محمية
router.use(protect);
router.use(adminOnly);

// Users
router.get("/users", getAllUsers);
router.get("/users/:id", getUserById);
router.patch("/users/:id", updateUserByAdmin);
router.delete("/users/:id", deleteUserByAdmin);
router.patch("/users/:id/toggle-active", toggleUserActiveStatus);

// Identity verification
router.get("/users/pending-identity", getPendingIdentities);
router.patch("/users/:id/identity-status", updateIdentityStatus);

// Contractors verification
router.get("/contractors/pending", getPendingContractors);
router.patch("/contractors/:id/status", updateContractorStatus);

module.exports = router;

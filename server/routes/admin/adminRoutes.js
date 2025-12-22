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
  getUserIdentityDetails,
} = require("../../controllers/adminController");

// ✅ تأكد إن اسم الملف مطابق عندك (authMiddleware.js)
const { protect, adminOnly, verifiedAndActive } = require("../../middleware/authMiddleware");

// ✅ كل مسارات الأدمن محمية + لازم يكون Verified + Active
router.use(protect);
router.use(adminOnly);
router.use(verifiedAndActive);

/* ===================== Users ===================== */

// GET /api/admin/users?role=client|contractor|admin (اختياري)
router.get("/users", getAllUsers);

// GET /api/admin/users/:role/:id
router.get("/users/:role/:id", getUserById);

// PATCH /api/admin/users/:role/:id
router.patch("/users/:role/:id", updateUserByAdmin);

// DELETE /api/admin/users/:role/:id
router.delete("/users/:role/:id", deleteUserByAdmin);

// PATCH /api/admin/users/:role/:id/toggle-active
router.patch("/users/:role/:id/toggle-active", toggleUserActiveStatus);

/* ===================== Identity verification ===================== */

// GET /api/admin/users/pending-identity
router.get("/users/pending-identity", getPendingIdentities);

// GET /api/admin/users/:role/:id/identity (client/contractor فقط)
router.get("/users/:role/:id/identity", getUserIdentityDetails);

// PATCH /api/admin/users/:role/:id/identity-status
router.patch("/users/:role/:id/identity-status", updateIdentityStatus);

/* ===================== Contractors verification ===================== */

// GET /api/admin/contractors/pending
router.get("/contractors/pending", getPendingContractors);

// PATCH /api/admin/contractors/:id/status
router.patch("/contractors/:id/status", updateContractorStatus);

module.exports = router;

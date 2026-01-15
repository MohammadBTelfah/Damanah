const express = require("express");
const router = express.Router();

router.get("/health", (req, res) => {
  return res.json({ ok: true, service: "admin" });
});

// ✅ بعدها الحماية لباقي المسارات
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

const { protect, adminOnly, verifiedAndActive } = require("../../middleware/authMiddleWare");

router.use(protect);
router.use(adminOnly);
router.use(verifiedAndActive);

/* Users */
router.get("/users", getAllUsers);
router.get("/users/:role/:id", getUserById);
router.patch("/users/:role/:id", updateUserByAdmin);
router.delete("/users/:role/:id", deleteUserByAdmin);
router.patch("/users/:role/:id/toggle-active", toggleUserActiveStatus);

/* Identity */
router.get("/users/pending-identity", getPendingIdentities);
router.get("/users/:role/:id/identity", getUserIdentityDetails);
router.patch("/users/:role/:id/identity-status", updateIdentityStatus);

/* Contractors */
router.get("/contractors/pending", getPendingContractors);
router.patch("/contractors/:id/status", updateContractorStatus);

module.exports = router;

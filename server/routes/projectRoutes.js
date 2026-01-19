const express = require("express");
const router = express.Router();
// لم نعد بحاجة لـ path و multer هنا
// const path = require("path");
// const multer = require("multer");

const projectController = require("../controllers/projectController");
const {
  protect,
  clientOnly,
  contractorOnly,
} = require("../middleware/authMiddleWare");

// ✅ NEW: استيراد إعدادات Cloudinary
const upload = require("../config/cloudinaryConfig");

// ================================
// ✅ Contractor routes (لازم قبل :projectId)
// ================================
router.get(
  "/contractor/available",
  protect,
  contractorOnly,
  projectController.getAvailableProjectsForContractor
);

router.get(
  "/contractor/my",
  protect,
  contractorOnly,
  projectController.getMyProjectsForContractor
);

// ================================
// Client routes
// ================================
router.post("/", protect, clientOnly, projectController.createProject);
router.get("/my", protect, clientOnly, projectController.getMyProjects);
router.get("/open", protect, contractorOnly, projectController.getOpenProjects);

// ✅ Contractors list for picker (client)
router.get(
  "/contractors/available",
  protect,
  clientOnly,
  projectController.getAvailableContractors
);

// ================================
// ✅ Project Actions
// ================================

// 🔥 NEW: Publish to all contractors
router.patch(
  "/:projectId/publish",
  protect,
  clientOnly,
  projectController.publishProject
);

// Estimate / Save / Download / Share / Assign
router.post("/:id/estimate", protect, clientOnly, projectController.estimateProject);
router.patch("/:id/save", protect, clientOnly, projectController.saveProject);
router.get("/:id/estimate/download", protect, clientOnly, projectController.downloadEstimate);
router.post("/:id/share", protect, clientOnly, projectController.shareProject);
router.patch("/:id/assign", protect, clientOnly, projectController.assignContractor);

// ================================
// ✅ Project by ID (آخر شي)
// ================================
router.get("/:projectId", protect, projectController.getProjectById);

// ================================
// Offers
// ================================
router.post(
  "/:projectId/offers",
  protect,
  contractorOnly,
  projectController.createOffer
);

router.get(
  "/contractor/my-offers",
  protect,
  contractorOnly,
  projectController.getContractorMyOffers
);

router.get(
  "/:projectId/offers",
  protect,
  clientOnly,
  projectController.getProjectOffers
);

router.patch(
  "/:projectId/offers/:offerId/accept",
  protect,
  clientOnly,
  projectController.acceptOffer
);

// ================================
// Plan analyze
// ================================
router.post(
  "/plan/analyze",
  protect,
  clientOnly,
  upload.single("planFile"), // ✅ التعديل هنا: استخدام Cloudinary Upload
  projectController.analyzePlanOnly
);

router.get(
  "/clients/my-contractors",
  protect,
  clientOnly,
  projectController.getMyContractors
);

// ... (تأكد أنك تضعه قبل الراوتات التي تحتوي على :id لتجنب التضارب)
router.get("/client/recent-offers", protect, projectController.getClientRecentOffers);

router.patch('/:id/status', protect, contractorOnly, projectController.updateProjectStatus);

module.exports = router;
const express = require("express");
const router = express.Router();
const path = require("path");
const multer = require("multer");

const projectController = require("../controllers/projectController");
const {
  protect,
  clientOnly,
  contractorOnly,
} = require("../middleware/authMiddleWare");

// ========= multer for plans =========
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, "uploads/plans/"),
  filename: (req, file, cb) =>
    cb(
      null,
      Date.now() +
        "-" +
        Math.round(Math.random() * 1e9) +
        path.extname(file.originalname)
    ),
});

const planUpload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
});

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

// ✅ Contractors list for picker (client) - لازم قبل :projectId
router.get(
  "/contractors/available",
  protect,
  clientOnly,
  projectController.getAvailableContractors
);

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
  planUpload.single("planFile"),
  projectController.analyzePlanOnly
);

// ================================
// Estimate / Save / Download / Share / Assign
// ================================
router.post("/:id/estimate", protect, clientOnly, projectController.estimateProject);
router.patch("/:id/save", protect, clientOnly, projectController.saveProject);
router.get("/:id/estimate/download", protect, clientOnly, projectController.downloadEstimate);
router.post("/:id/share", protect, clientOnly, projectController.shareProject);
router.patch("/:id/assign", protect, clientOnly, projectController.assignContractor);

module.exports = router;

const express = require("express");
const router = express.Router();
const path = require("path");
const multer = require("multer");

const projectController = require("../controllers/projectController");
const { protect, clientOnly, contractorOnly } = require("../middleware/authMiddleWare");

// ========= multer for plans =========
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, "uploads/plans/"),
  filename: (req, file, cb) =>
    cb(
      null,
      Date.now() + "-" + Math.round(Math.random() * 1e9) + path.extname(file.originalname)
    ),
});

const planUpload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
});

// ========= Project CRUD =========

// create project (client)
router.post("/", protect, clientOnly, projectController.createProject);

// my projects (client)
router.get("/my", protect, clientOnly, projectController.getMyProjects);

// open projects (contractor)
router.get("/open", protect, contractorOnly, projectController.getOpenProjects);

// get project by id
router.get("/:projectId", protect, projectController.getProjectById);

// ========= Offers =========

// contractor create offer
router.post("/:projectId/offers", protect, contractorOnly, projectController.createOffer);

// client get offers
router.get("/:projectId/offers", protect, clientOnly, projectController.getProjectOffers);

// client accept offer
router.patch(
  "/:projectId/offers/:offerId/accept",
  protect,
  clientOnly,
  projectController.acceptOffer
);

// ========= Plan analyze =========
router.post(
  "/plan/analyze",
  protect,
  clientOnly,
  planUpload.single("planFile"),
  projectController.analyzePlanOnly
);

// ========= Estimate =========
router.post("/:id/estimate", protect, clientOnly, projectController.estimateProject);

// ========= NEW: Save / Download / Share / Assign =========
router.patch("/:id/save", protect, clientOnly, projectController.saveProject);

router.get("/:id/estimate/download", protect, clientOnly, projectController.downloadEstimate);

router.post("/:id/share", protect, clientOnly, projectController.shareProject);

router.patch("/:id/assign", protect, clientOnly, projectController.assignContractor);

module.exports = router;

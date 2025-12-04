const express = require("express");
const router = express.Router();
const path = require("path");
const multer = require("multer");

const {
  createProject,
  getMyProjects,
  getOpenProjects,
  getProjectById,
  createOffer,
  getProjectOffers,
  acceptOffer,
  uploadPlanAndEstimate,
} = require("../controllers/projectController");

const {
  protect,
  clientOnly,
  contractorOnly,
} = require("../middleware/authMiddleWare");

// إعداد التخزين لملفات المخططات
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
  fileFilter: (req, file, cb) => {
    const allowed = ["image/png", "image/jpeg", "application/pdf"];
    if (allowed.includes(file.mimetype)) cb(null, true);
    else cb(new Error("Invalid file type"), false);
  },
});

// إنشاء مشروع جديد (client فقط)
router.post("/", protect, clientOnly, createProject);

// مشاريعي (client)
router.get("/my", protect, clientOnly, getMyProjects);

// المشاريع المفتوحة (contractor)
router.get("/open", protect, contractorOnly, getOpenProjects);

// مشروع معيّن
router.get("/:projectId", protect, getProjectById);

// المقاول يقدّم عرض
router.post("/:projectId/offers", protect, contractorOnly, createOffer);

// العميل يشوف العروض
router.get("/:projectId/offers", protect, clientOnly, getProjectOffers);

// العميل يقبل عرض معيّن
router.patch(
  "/:projectId/offers/:offerId/accept",
  protect,
  clientOnly,
  acceptOffer
);

// رفع مخطط + Mock AI + BOQ
router.post(
  "/:projectId/plan",
  protect,
  clientOnly,
  planUpload.single("planFile"),
  uploadPlanAndEstimate
);

module.exports = router;

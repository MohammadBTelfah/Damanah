const express = require("express");
const router = express.Router();

const {
  createProject,
  getMyProjects,
  getOpenProjects,
  getProjectById,
  createOffer,
  getProjectOffers,
  acceptOffer,
} = require("../controllers/projectController");

const {
  protect,
  clientOnly,
  contractorOnly,
} = require("../middleware/authMiddleWare");

// إنشاء مشروع (client فقط)
router.post("/", protect, clientOnly, createProject);

// مشاريعي (client)
router.get("/my", protect, clientOnly, getMyProjects);

// المشاريع المفتوحة (contractor)
router.get("/open", protect, contractorOnly, getOpenProjects);

// المقاول يقدّم عرض على مشروع
router.post("/:projectId/offers", protect, contractorOnly, createOffer);

// العميل يشوف العروض على مشروعه
router.get("/:projectId/offers", protect, clientOnly, getProjectOffers);

// العميل يقبل عرض معيّن
router.patch(
  "/:projectId/offers/:offerId/accept",
  protect,
  clientOnly,
  acceptOffer
);

// مشروع معيّن (أي مستخدم مسجّل يقدر يشوف التفاصيل)
router.get("/:projectId", protect, getProjectById);

module.exports = router;

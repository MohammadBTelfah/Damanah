const express = require("express");
const router = express.Router();

// انتبه: عندك هنا authMiddleware (مش authMiddleWare)
// خليها زي مشروعك الحالي
const { protect } = require("../middleware/authMiddleWare");
const contractController = require("../controllers/contractController");

// GET /api/contracts
router.get("/", protect, contractController.getMyContracts);

// GET /api/contracts/:id
router.get("/:id", protect, contractController.getContractById);

// ✅ NEW: POST /api/contracts (Create + Generate PDF)
router.post("/", protect, contractController.createContract);

// ✅ NEW: GET /api/contracts/:id/pdf (Download/Preview PDF)
router.get("/:id/pdf", protect, contractController.getContractPdf);

module.exports = router;

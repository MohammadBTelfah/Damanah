const express = require("express");
const router = express.Router();
const { protect } = require("../middleware/authMiddleware"); // تأكد من المسار
const contractController = require("../controllers/contractController");

// GET /api/contracts
router.get("/", protect, contractController.getMyContracts);

// GET /api/contracts/:id
router.get("/:id", protect, contractController.getContractById);

module.exports = router;
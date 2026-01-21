const express = require("express");
const router = express.Router();
const tipController = require("../controllers/tipController");

router.get("/", tipController.getAllTips);
router.post("/", tipController.createTip);

module.exports = router;
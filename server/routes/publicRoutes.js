const router = require("express").Router();
const jcca = require("../controllers/jccaNewsController");

// public endpoint (بدون توكن)
router.get("/jcca-news", jcca.getJccaNews);

module.exports = router;

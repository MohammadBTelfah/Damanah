const router = require("express").Router();
const jcca = require("../controllers/jccaNewsController");

router.get("/jcca-news", jcca.getJccaNews);

module.exports = router;

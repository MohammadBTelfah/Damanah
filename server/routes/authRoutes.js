const express = require("express");
const router = express.Router();
const multer = require("multer");
const path = require("path");

const { register, login } = require("../controllers/authController");

// إعداد التخزين
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, "uploads/"),
  filename: (req, file, cb) =>
    cb(
      null,
      Date.now() +
        "-" +
        Math.round(Math.random() * 1e9) +
        path.extname(file.originalname)
    ),
});

const fileFilter = (req, file, cb) => {
  const allowed = ["image/jpeg", "image/png", "application/pdf"];
  if (allowed.includes(file.mimetype)) cb(null, true);
  else cb(new Error("Invalid file type"), false);
};

const upload = multer({ storage, fileFilter });

// identityDocument: هوية مدنية
// contractorDocument: وثيقة المقاول
router.post(
  "/register",
  upload.fields([
    { name: "identityDocument", maxCount: 1 },
    { name: "contractorDocument", maxCount: 1 },
  ]),
  register
);

router.post("/login", login);

module.exports = router;

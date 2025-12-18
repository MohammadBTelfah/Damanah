const express = require("express");
const router = express.Router();
const multer = require("multer");
const path = require("path");

const {
  register,
  login,
  verifyEmail,
  resendVerificationEmail,
} = require("../controllers/authController");

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


const allowedMime = [
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/gif",
  "image/webp",
  "image/svg+xml",
  "image/tiff",
  "application/pdf",
];

// الامتدادات المسموحة (احتياط)
const allowedExt = [
  ".jpg",
  ".jpeg",
  ".png",
  ".gif",
  ".webp",
  ".svg",
  ".tiff",
  ".pdf",
];

const fileFilter = (req, file, cb) => {
  console.log("Uploaded file:", file.originalname, file.mimetype);

  const ext = path.extname(file.originalname).toLowerCase();

  // ✅ إذا الميم تايب معروف ومسموح
  if (allowedMime.includes(file.mimetype)) {
    return cb(null, true);
  }

  // ✅ Flutter أحيانًا يبعث octet-stream → نتحقق من الامتداد
  if (
    file.mimetype === "application/octet-stream" &&
    allowedExt.includes(ext)
  ) {
    return cb(null, true);
  }

  return cb(
    new Error("Only image files (JPG, PNG, etc.) and PDF are allowed"),
    false
  );
};

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
});

// Register
router.post(
  "/register",
  upload.fields([
    { name: "identityDocument", maxCount: 1 },
    { name: "contractorDocument", maxCount: 1 },
    { name: "profileImage", maxCount: 1 },
  ]),
  register
);

// Login
router.post("/login", login);

// Verify Email
router.get("/verify-email/:token", verifyEmail);

// Resend Verification Email
router.post("/resend-verification-email", resendVerificationEmail);

module.exports = router;

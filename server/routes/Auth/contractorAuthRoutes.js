const router = require("express").Router();
const contractorAuth = require("../../controllers/Auth/contractorAuthcontroller");
const multer = require("multer");
const path = require("path");
const fs = require("fs");

/* ================== UPLOAD SETUP ================== */
function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    let folder = "misc";
    if (file.fieldname === "profileImage") folder = "profiles";
    if (file.fieldname === "identityDocument") folder = "identity";
    if (file.fieldname === "contractorDocument") folder = "contractor_docs";

    const uploadPath = path.join(process.cwd(), "uploads", folder);
    ensureDir(uploadPath);
    cb(null, uploadPath);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
  },
});

function fileFilter(req, file, cb) {
  if (file.fieldname === "profileImage" || file.fieldname === "contractorDocument") {
    if (file.mimetype.startsWith("image/")) return cb(null, true);
    return cb(new Error(`${file.fieldname} must be an image`), false);
  }

  if (file.fieldname === "identityDocument") {
    const ok =
      file.mimetype.startsWith("image/") ||
      file.mimetype === "application/pdf";
    if (ok) return cb(null, true);
    return cb(new Error("identityDocument must be image or PDF"), false);
  }

  cb(new Error("Unexpected file field"), false);
}

const upload = multer({ storage, fileFilter });

/* ================== ROUTES (NO AUTH) ================== */

// register
router.post(
  "/register",
  upload.fields([
    { name: "profileImage", maxCount: 1 },
    { name: "identityDocument", maxCount: 1 },
    { name: "contractorDocument", maxCount: 1 },
  ]),
  contractorAuth.register
);

// login
router.post("/login", contractorAuth.login);

// ✅ email verification
router.get("/verify-email/:token", contractorAuth.verifyEmail);

// ✅ resend verification email
router.post("/resend-verification", contractorAuth.resendVerificationEmail);

module.exports = router;

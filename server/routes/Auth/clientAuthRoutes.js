const router = require("express").Router();
const clientAuth = require("../../controllers/Auth/clientauthcontroller");
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
  const forbidden = [
    "application/x-msdownload", // exe
    "application/x-sh",
    "application/x-bat",
  ];

  if (forbidden.includes(file.mimetype)) {
    return cb(new Error("File type not allowed"), false);
  }

  cb(null, true);
}

const upload = multer({ storage, fileFilter });


/* ================== ROUTES (NO AUTH) ================== */

// register
router.post(
  "/register",
  upload.fields([
    { name: "profileImage", maxCount: 1 },
    { name: "identityDocument", maxCount: 1 },
  ]),
  clientAuth.register
);

// login
router.post("/login", clientAuth.login);

// ✅ email verification
router.get("/verify-email/:token", clientAuth.verifyEmail);

// ✅ resend verification email
router.post("/resend-verification", clientAuth.resendVerificationEmail);

module.exports = router;

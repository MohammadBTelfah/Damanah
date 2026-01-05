const multer = require("multer");
const path = require("path");
const fs = require("fs");

/**
 * utils/upload.js
 * __dirname = server/utils
 * نطلع خطوة واحدة → server/
 */
const SERVER_ROOT = path.join(__dirname, "..");
const UPLOADS_DIR = path.join(SERVER_ROOT, "uploads");

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function createStorage(folderName) {
  return multer.diskStorage({
    destination: (req, file, cb) => {
      const uploadPath = path.join(UPLOADS_DIR, folderName);
      ensureDir(uploadPath);
      cb(null, uploadPath);
    },
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname).toLowerCase() || ".jpg";
      const safeName = `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`;
      cb(null, safeName);
    },
  });
}

function imageOnlyFilter(req, file, cb) {
  const mimeOk = file.mimetype && file.mimetype.startsWith("image/");
  const ext = path.extname(file.originalname || "").toLowerCase();
  const extOk = [".jpg", ".jpeg", ".png", ".webp", ".heic"].includes(ext);

  if (mimeOk || extOk) return cb(null, true);
  cb(new Error("Only image files are allowed"), false);
}

function pdfOrImageFilter(req, file, cb) {
  const mime = file.mimetype || "";
  const ext = path.extname(file.originalname || "").toLowerCase();

  const isImg =
    mime.startsWith("image/") ||
    [".jpg", ".jpeg", ".png", ".webp", ".heic"].includes(ext);

  const isPdf = mime === "application/pdf" || ext === ".pdf";

  if (isImg || isPdf) return cb(null, true);
  cb(new Error("Only images or PDF are allowed"), false);
}

// ✅ profile images
const uploadProfileImage = multer({
  storage: createStorage("profiles"),
  fileFilter: imageOnlyFilter,
  limits: { fileSize: 5 * 1024 * 1024 },
});

// ✅ identity docs
const uploadIdentityDoc = multer({
  storage: createStorage("identity"),
  fileFilter: pdfOrImageFilter,
  limits: { fileSize: 10 * 1024 * 1024 },
});

// ✅ contractor docs
const uploadContractorDoc = multer({
  storage: createStorage("contractor_docs"),
  fileFilter: imageOnlyFilter,
  limits: { fileSize: 10 * 1024 * 1024 },
});

module.exports = {
  uploadProfileImage,
  uploadIdentityDoc,
  uploadContractorDoc,
};

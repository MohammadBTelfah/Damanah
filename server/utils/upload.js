const multer = require("multer");
const path = require("path");
const fs = require("fs");

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function createStorage(folderName) {
  return multer.diskStorage({
    destination: (req, file, cb) => {
      const uploadPath = path.join(process.cwd(), "uploads", folderName);
      ensureDir(uploadPath);
      cb(null, uploadPath);
    },
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname).toLowerCase();
      const safeName = `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`;
      cb(null, safeName);
    },
  });
}

function imageOnlyFilter(req, file, cb) {
  if (file.mimetype && file.mimetype.startsWith("image/")) return cb(null, true);
  cb(new Error("Only image files are allowed"), false);
}

function pdfOrImageFilter(req, file, cb) {
  const ok =
    (file.mimetype && file.mimetype.startsWith("image/")) ||
    file.mimetype === "application/pdf";
  if (ok) return cb(null, true);
  cb(new Error("Only images or PDF are allowed"), false);
}

// ✅ profile images (image only)
const uploadProfileImage = multer({
  storage: createStorage("profiles"),
  fileFilter: imageOnlyFilter,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
});

// ✅ identity docs (image or pdf)
const uploadIdentityDoc = multer({
  storage: createStorage("identity"),
  fileFilter: pdfOrImageFilter,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
});

// ✅ contractor docs (image only)
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

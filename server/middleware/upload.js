const multer = require("multer");
const path = require("path");
const fs = require("fs");

const uploadDir = "uploads";
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir);

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const name = `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`;
    cb(null, name);
  },
});

const IMAGE_EXT = [".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif"];
const DOC_EXT = [...IMAGE_EXT, ".pdf"];

function isImageByMime(file) {
  return file.mimetype && file.mimetype.startsWith("image/");
}

function isPdfByMime(file) {
  return file.mimetype === "application/pdf";
}

const fileFilter = (req, file, cb) => {
  const ext = path.extname(file.originalname).toLowerCase();

  // ✅ حسب اسم الحقل
  if (file.fieldname === "profileImage") {
    // صور فقط
    const ok = isImageByMime(file) || IMAGE_EXT.includes(ext);
    if (!ok) return cb(new Error("Only images allowed"), false);
    return cb(null, true);
  }

  if (file.fieldname === "identityDocument" || file.fieldname === "contractorDocument") {
    // صور أو PDF
    const ok = isImageByMime(file) || isPdfByMime(file) || DOC_EXT.includes(ext);
    if (!ok) return cb(new Error("Only images or PDF allowed"), false);
    return cb(null, true);
  }

  // أي حقل ثاني: ارفضه
  return cb(new Error("Invalid file field"), false);
};

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
});

module.exports = upload;

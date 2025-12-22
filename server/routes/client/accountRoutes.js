const router = require("express").Router();
const me = require("../../controllers/meController");
const { protect, clientOnly, verifiedAndActive } = require("../../middleware/authMiddleWare");

const multer = require("multer");
const path = require("path");
const fs = require("fs");

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadPath = path.join(process.cwd(), "uploads", "profiles");
    ensureDir(uploadPath);
    cb(null, uploadPath);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
  },
});

function fileFilter(req, file, cb) {
  if (file.mimetype.startsWith("image/")) return cb(null, true);
  cb(new Error("profileImage must be an image"), false);
}

const upload = multer({ storage, fileFilter });

router.get("/me", protect, clientOnly, verifiedAndActive, me.getMe);
router.put("/me", protect, clientOnly, verifiedAndActive, upload.single("profileImage"), me.updateMe);
router.delete("/me", protect, clientOnly, verifiedAndActive, me.deleteMe);

router.put("/change-password", protect, clientOnly, verifiedAndActive, me.changePassword);

module.exports = router;

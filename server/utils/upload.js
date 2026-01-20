const multer = require("multer");
const { CloudinaryStorage } = require("multer-storage-cloudinary");
const cloudinary = require("../config/cloudinaryConfig");

// 1. تخزين صور البروفايل (صور فقط)
const profileStorage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "damanah/profiles",
    allowed_formats: ["jpg", "png", "jpeg", "webp"],
  },
});

// 2. تخزين الهويات والمستندات (يدعم PDF وصور)
const docStorage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "damanah/documents", // غيرت الاسم ليكون عاماً أكثر
    resource_type: "auto", 
    allowed_formats: ["jpg", "png", "jpeg", "pdf"],
  },
});

const planStorage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "damanah/plans", // سيتم حفظها في مجلد منفصل ومرتب
    resource_type: "auto",   // يدعم PDF والصور
    allowed_formats: ["jpg", "png", "jpeg", "pdf"],
  },
});

// تعريف الـ Middleware
const uploadProfileImage = multer({ storage: profileStorage });
const uploadIdentityDoc = multer({ storage: docStorage });   // ✅ يدعم PDF
const uploadContractorDoc = multer({ storage: docStorage }); // ✅ يدعم PDF الآن
const uploadPlan = multer({ storage: planStorage });
module.exports = {
  uploadProfileImage,
  uploadIdentityDoc,
  uploadContractorDoc,
  uploadPlan
};
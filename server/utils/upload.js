const multer = require("multer");
const { CloudinaryStorage } = require("multer-storage-cloudinary");

// ✅ التعديل هنا: نستدعي ملف الكونفيج الجاهز بدلاً من إعداد المكتبة مرة أخرى
const cloudinary = require("../config/cloudinaryConfig");

// 1. إعداد تخزين صور البروفايل
const profileStorage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "damanah/profiles",
    allowed_formats: ["jpg", "png", "jpeg", "webp"],
  },
});

// 2. إعداد تخزين الهويات (يدعم PDF والصور)
const identityStorage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "damanah/identity",
    resource_type: "auto", // مهم جداً لدعم PDF
    allowed_formats: ["jpg", "png", "jpeg", "pdf"],
  },
});

// 3. إعداد تخزين مستندات المقاول (اختياري، يمكن دمجها)
const contractorStorage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "damanah/contractor_docs",
    resource_type: "auto",
    allowed_formats: ["jpg", "png", "jpeg", "pdf"],
  },
});

// تعريف الـ Middleware
const uploadProfileImage = multer({ storage: profileStorage });
const uploadIdentityDoc = multer({ storage: identityStorage });
const uploadContractorDoc = multer({ storage: contractorStorage });

module.exports = {
  uploadProfileImage,
  uploadIdentityDoc,
  uploadContractorDoc,
};
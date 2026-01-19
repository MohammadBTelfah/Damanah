const multer = require("multer");
const { CloudinaryStorage } = require("multer-storage-cloudinary");
const { cloudinary } = require("../config/cloudinary"); // تأكد من إنشاء هذا الملف

// إعداد التخزين السحابي لصور البروفايل
const profileStorage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "damanah/profiles",
    allowed_formats: ["jpg", "png", "jpeg", "webp"],
  },
});

// إعداد التخزين السحابي للهويات (يدعم PDF وصور)
const identityStorage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "damanah/identity",
    resource_type: "auto", // مهم جداً لدعم الـ PDF والصور معاً
    allowed_formats: ["jpg", "png", "jpeg", "pdf"],
  },
});

// تصدير الـ Middleware لاستخدامها في الـ Routes
const uploadProfileImage = multer({ storage: profileStorage });
const uploadIdentityDoc = multer({ storage: identityStorage });
const uploadContractorDoc = multer({ storage: profileStorage }); // يمكنك استخدام نفس إعداد البروفايل

module.exports = {
  uploadProfileImage,
  uploadIdentityDoc,
  uploadContractorDoc,
};
const cloudinary = require('cloudinary').v2;
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const multer = require('multer');
const dotenv = require('dotenv');

dotenv.config();

// إعداد بيانات الاتصال
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// إعداد التخزين (هنا السحر!)
const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: 'damanah_uploads', // اسم المجلد الذي سيتم إنشاؤه في حسابك
    allowed_formats: ['jpg', 'png', 'jpeg', 'pdf'],
  },
});

const upload = multer({ storage: storage });

module.exports = upload;
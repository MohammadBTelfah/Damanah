const mongoose = require("mongoose");

const clientSchema = new mongoose.Schema(
  {
    // --- البيانات الأساسية ---
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    password: { type: String, required: true, minlength: 6 },
    role: { type: String, enum: ["client"], default: "client" },
    profileImage: { type: String, default: null },
    phone: { type: String, required: true },

    /* ================= Identity (الهوية) ================= */

    // 1. صورة الهوية (رابط Cloudinary)
    identityDocument: { type: String, default: null },

    // 2. الرقم الوطني النهائي المعتمد (يوضع يدوياً أو يُعتمد من الأدمن)
    nationalId: { type: String, default: null },

    // 3. حالة التحقق من الهوية
    identityStatus: {
      type: String,
      enum: ["none", "pending", "verified", "rejected"],
      default: "none", // تصبح "pending" عند رفع هوية
    },
    // fullNameFromId:
    // Stores the official English name extracted from national ID
    // or manually corrected by the user/admin.

    fullNameFromId: {
      type: String,
      default: null,
    },


    // 4. بيانات الذكاء الاصطناعي (OCR Data)
    // نخزن هنا ما قرأه النظام تلقائياً لنساعد الأدمن في القرار
    identityData: {
      extractedName: { type: String, default: null },       // الاسم المستخرج من الهوية
      extractedNationalId: { type: String, default: null }, // الرقم الوطني المقترح من OCR
      confidence: { type: Number, default: 0 },             // نسبة الثقة في القراءة
      rawText: { type: String, default: null },             // النص الكامل المستخرج (للتشخيص)
      extractedAt: { type: Date, default: Date.now }
    },

    /* ================= Account Status ================= */

    isActive: { type: Boolean, default: false },

    emailVerified: { type: Boolean, default: false },
    emailVerificationToken: { type: String, default: null },
    emailVerificationExpires: { type: Date, default: null },

    resetPasswordToken: { type: String, default: null },
    resetPasswordExpires: { type: Date, default: null },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Client", clientSchema);
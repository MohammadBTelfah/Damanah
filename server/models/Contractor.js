const mongoose = require("mongoose");

const contractorSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },

    email: { type: String, required: true, unique: true },

    password: { type: String, required: true, minlength: 6 },

    role: { type: String, enum: ["contractor"], default: "contractor" },

    profileImage: { type: String, default: null },

    phone: { type: String, required: true },

    // حالة توفر المقاول لاستلام مشاريع جديدة
    availabilityStatus: {
      type: String,
      enum: ["available", "busy", "unavailable"], // متاح، مشغول، غير متواجد حالياً
      default: "available",
    },

    // ملف هوية مدنية (صورة أو PDF)
    identityDocument: { type: String, default: null },

    // الرقم الوطني (من Scan / OCR)
    nationalId: { type: String, default: null },

    // نسبة الثقة 0 → 1
    nationalIdConfidence: { type: Number, default: null, min: 0, max: 1 },

    // وقت استخراج البيانات من الهوية
    identityExtractedAt: { type: Date, default: null },
    // اقتراح OCR (لا يطغى على الرقم اليدوي)
    nationalIdCandidate: { type: String, default: null },

    // النص المستخرج من OCR (اختياري – للتشخيص)
    identityRawText: { type: String, default: null },

    // حالة التحقق من الهوية من الأدمن
    identityStatus: {
      type: String,
      enum: ["none", "pending", "verified", "rejected"],
      default: "none",
    },

    // وثيقة المقاول المهنية (رخصة / سجل)
    contractorDocument: { type: String, default: null },

    // حالة التحقق من المقاول
    contractorStatus: {
      type: String,
      enum: ["pending", "verified", "rejected"],
      default: "pending",
    },

    // تفعيل / تعطيل الحساب
    isActive: { type: Boolean, default: false },

    // تفعيل الإيميل
    emailVerified: { type: Boolean, default: false },
    emailVerificationToken: { type: String, default: null },
    emailVerificationExpires: { type: Date, default: null },

    // استعادة كلمة المرور
    resetPasswordToken: { type: String, default: null },
    resetPasswordExpires: { type: Date, default: null },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Contractor", contractorSchema);

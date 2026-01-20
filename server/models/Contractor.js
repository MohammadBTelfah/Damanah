const mongoose = require("mongoose");

const contractorSchema = new mongoose.Schema(
  {
    // --- البيانات الأساسية ---
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    password: { type: String, required: true, minlength: 6 },
    role: { type: String, enum: ["contractor"], default: "contractor" },
    profileImage: { type: String, default: null },
    phone: { type: String, required: true },

    // حالة توفر المقاول لاستلام مشاريع جديدة
    availabilityStatus: {
      type: String,
      enum: ["available", "busy", "unavailable"],
      default: "available",
    },

    /* ================= Identity (الهوية الشخصية) ================= */

    // 1. صورة الهوية (رابط Cloudinary)
    identityDocument: { type: String, default: null },

    // 2. الرقم الوطني النهائي المعتمد (يدوي أو موافقة أدمن)
    nationalId: { type: String, default: null },

    // 3. حالة التحقق من الهوية
    identityStatus: {
      type: String,
      enum: ["none", "pending", "verified", "rejected"],
      default: "none",
    },

    // 4. بيانات الذكاء الاصطناعي (OCR Data)
    identityData: {
      extractedName: { type: String, default: null },       // الاسم المستخرج
      extractedNationalId: { type: String, default: null }, // الرقم الوطني المقترح
      confidence: { type: Number, default: 0 },             // نسبة الثقة
      rawText: { type: String, default: null },             // النص الخام
      extractedAt: { type: Date, default: Date.now }
    },

    /* ================= Contractor Documents (الوثائق المهنية) ================= */

    // وثيقة المقاول المهنية (رخصة مهن / سجل تجاري) - رابط Cloudinary
    contractorDocument: { type: String, default: null },

    // حالة التحقق من وثائق المقاولة (منفصلة عن الهوية الشخصية)
    contractorStatus: {
      type: String,
      enum: ["pending", "verified", "rejected"],
      default: "pending",
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

module.exports = mongoose.model("Contractor", contractorSchema);
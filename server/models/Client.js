const mongoose = require("mongoose");

const clientSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },

    email: { type: String, required: true, unique: true },
    password: { type: String, required: true, minlength: 6 },

    role: { type: String, enum: ["client"], default: "client" },

    profileImage: { type: String, default: null },
    phone: { type: String, required: true },

    /* ================= Identity ================= */

    // ملف هوية مدنية (صورة أو PDF)
    identityDocument: { type: String, default: null },

    // الرقم الوطني المؤكد (يدوي أو بعد موافقة الأدمن)
    nationalId: { type: String, default: null },

    // ✅ اقتراح OCR (لا يطغى على الرقم اليدوي)
    nationalIdCandidate: { type: String, default: null },

    // نسبة الثقة 0 → 1
    nationalIdConfidence: { type: Number, default: null, min: 0, max: 1 },

    // النص المستخرج من OCR (اختياري – للتشخيص)
    identityRawText: { type: String, default: null },

    // وقت استخراج البيانات من الهوية
    identityExtractedAt: { type: Date, default: null },

    // حالة التحقق من الهوية من الأدمن
    identityStatus: {
      type: String,
      enum: ["none", "pending", "verified", "rejected"],
      default: "none",
    },

    /* ================= Account ================= */

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

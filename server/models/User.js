const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },

    email: {
      type: String,
      required: true,
      unique: true,
    },

    password: {
      type: String,
      required: true,
      minlength: 6,
    },

    phone: {
      type: String,
      required: true,
    },

    role: {
      type: String,
      enum: ["client", "contractor", "admin"],
      default: "client",
    },

    // ملف هوية مدنية (صورة أو PDF) لكل المستخدمين
    identityDocument: {
      type: String,
      default: null,
    },

    // حالة التحقق من الهوية من الأدمن
    identityStatus: {
      type: String,
      enum: ["pending", "verified", "rejected"],
      default: "pending",
    },

    // وثيقة المقاول المهنية (رخصة / سجل)
    contractorDocument: {
      type: String,
      default: null,
    },

    // حالة التحقق من المقاول
    contractorStatus: {
      type: String,
      enum: ["pending", "verified", "rejected"],
      default: "pending",
    },

    // تفعيل / تعطيل الحساب
    isActive: {
      type: Boolean,
      default: true,
    },

    // لاستعادة كلمة المرور
    resetPasswordToken: {
      type: String,
      default: null,
    },
    resetPasswordExpires: {
      type: Date,
      default: null,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("User", userSchema);

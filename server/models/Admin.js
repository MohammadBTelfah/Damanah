const mongoose = require("mongoose");

const adminSchema = new mongoose.Schema(
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

    role: {
      type: String,
      enum: [ "admin"],
      default: "admin",
    },

    profileImage: {
      type: String,
      default: null,
    },

    phone: {
      type: String,
      required: true,
    },

    // تفعيل / تعطيل الحساب
    isActive: {
      type: Boolean,
      default: true,
    },

    // الأدمن غالبًا إيميله مفعّل
    emailVerified: {
      type: Boolean,
      default: true,
    },
    

    // توكن تفعيل الإيميل (لو احتجته لاحقًا)
    emailVerificationToken: {
      type: String,
      default: null,
    },

    emailVerificationExpires: {
      type: Date,
      default: null,
    },

    // استعادة كلمة المرور
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

module.exports = mongoose.model("Admin", adminSchema);

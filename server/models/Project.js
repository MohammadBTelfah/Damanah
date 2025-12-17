const mongoose = require("mongoose");

const projectSchema = new mongoose.Schema(
  {
    owner: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true, // صاحب المشروع (العميل)
    },

    contractor: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null, // يتحدد بعد قبول عرض
    },

    title: { type: String, required: true },
    description: { type: String },
    location: { type: String },

    // بيانات هندسية أساسية
    area: { type: Number }, // مساحة البناء بالمتر المربع
    floors: { type: Number }, // عدد الطوابق
    finishingLevel: { type: String }, // عادي / متوسط / فاخر ... الخ

    // حالة المشروع
    status: {
      type: String,
      enum: ["open", "in_progress", "completed", "cancelled"],
      default: "open",
    },

    // ملف مخطط البيت (صورة / PDF)
    planFile: {
      type: String,
      default: null,
    },

    // نتيجة تحليل المخطط (من الـ AI أو Mock)
    planAnalysis: {
      totalArea: Number,
      floors: Number,
      rooms: Number,
      bathrooms: Number,
    },

    // نتيجة حساب الكميات (BOQ)
    estimation: {
      items: [
        {
          name: String, // steel, paint, blocks...
          quantity: Number,
          unit: String,
          pricePerUnit: Number,
          total: Number,
        },
      ],
      totalCost: { type: Number, default: 0 },
      currency: { type: String, default: "JOD" },
    },

    // عروض المقاولين على المشروع
    offers: [
      {
        contractor: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
          required: true,
        },
        price: { type: Number, required: true },
        message: { type: String },
        status: {
          type: String,
          enum: ["pending", "accepted", "rejected"],
          default: "pending",
        },
        createdAt: { type: Date, default: Date.now },
      },
    ],
  },
  { timestamps: true }
);

module.exports = mongoose.model("Project", projectSchema);

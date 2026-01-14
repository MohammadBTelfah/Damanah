// models/Project.js
const mongoose = require("mongoose");

const projectSchema = new mongoose.Schema(
  {
    owner: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Client", // ✅ بما إن صاحب المشروع عميل
      required: true,
    },

    contractor: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Contractor", // ✅ المقاول المختار
      default: null,
    },

    title: { type: String, required: true },
    description: { type: String, default: "" },
    location: { type: String, default: "" },

    area: { type: Number },
    floors: { type: Number },
    finishingLevel: { type: String, default: "basic" },

    buildingType: {
      type: String,
      enum: ["apartment", "villa", "commercial"],
      default: "apartment",
    },

    status: {
      type: String,
      enum: ["open", "in_progress", "completed", "cancelled"],
      default: "open",
    },

    planFile: { type: String, default: null },

    planAnalysis: {
      totalArea: Number,
      floors: Number,
      rooms: Number,
      bathrooms: Number,
    },

    estimation: {
      items: [
        {
          name: String,
          quantity: Number,
          unit: String,
          pricePerUnit: Number,
          total: Number,

          // ✅ optional: عشان تربط الاختيار بالمادة والـ variant
          materialId: String,
          variantKey: String,
        },
      ],
      totalCost: { type: Number, default: 0 },
      currency: { type: String, default: "JOD" },
      finishingLevel: { type: String, default: "basic" },
    },

    // ✅ زر "Save project"
    isSaved: { type: Boolean, default: false },

    // ✅ مشاركة المشروع
    sharedWith: [
      {
        type: mongoose.Schema.Types.ObjectId,
        refPath: "sharedWithModel", // ✅ ديناميكي
      },
    ],
    sharedWithModel: {
      type: String,
      enum: ["Contractor"], // ✅ حاليا فقط مقاولين
      default: "Contractor",
    },

    offers: [
      {
        contractor: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Contractor", // ✅ عندك Contractor موديل
          required: true,
        },
        price: { type: Number, required: true },
        message: { type: String, default: "" },
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

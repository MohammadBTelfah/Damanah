// models/Project.js
const mongoose = require("mongoose");

const projectSchema = new mongoose.Schema(
  {
    owner: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Client",
      required: true,
    },

    contractor: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Contractor",
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
      enum: ["House", "villa", "commercial"],
      default: "House",
    },

    // =============================
    // Status
    // =============================
    status: {
      type: String,
      enum: ["draft", "open", "in_progress", "completed", "cancelled"],
      default: "draft",
    },

    planFile: { type: String, default: null },

    // ✅ تحديث حقول تحليل المخطط لدعم الحصر الهندسي الدقيق
    planAnalysis: {
      totalArea: Number,
      floors: Number,
      rooms: Number,
      bathrooms: Number,
      
      // الإضافات المعمارية الجديدة:
      wallPerimeterLinear: { type: Number, default: 0 }, // إجمالي طول الجدران
      ceilingHeight: { type: Number, default: 3.0 },      // ارتفاع السقف الصافي
      
      openings: {
        windows: {
          count: { type: Number, default: 0 },
          estimatedTotalArea: { type: Number, default: 0 }
        },
        internalDoors: {
          count: { type: Number, default: 0 }
        },
        entranceDoors: {
          count: { type: Number, default: 0 }
        },
        voids: { // الفتحات المفقودة (المناور/المنور)
          count: { type: Number, default: 0 },
          totalVoidArea: { type: Number, default: 0 },
          voidPerimeter: { type: Number, default: 0 }
        }
      },
      confidence: Number,
      notes: [String]
    },

    // =============================
    // Program Estimation (مرجع فقط)
    // =============================
    estimation: {
      items: [
        {
          name: String,
          quantity: Number,
          unit: String,
          pricePerUnit: Number,
          total: Number,
          materialId: String,
          variantKey: String,
          variantLabel: String, // أضفته لضمان عرض اسم النوع (Basic/Premium)
        },
      ],
      totalCost: { type: Number, default: 0 },
      currency: { type: String, default: "JOD" },
      finishingLevel: { type: String, default: "basic" },
      // إضافة metadata لتخزين تفاصيل الحسابات النهائية للرجوع إليها
      metadata: mongoose.Schema.Types.Mixed 
    },

    // =============================
    // ✅ السعر المتفق عليه
    // =============================
    agreedPrice: {
      type: Number,
      default: null,
    },

    // =============================
    // ✅ العرض المقبول (snapshot)
    // =============================
    acceptedOffer: {
      contractor: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Contractor",
      },
      price: Number,
      message: String,
      offerId: mongoose.Schema.Types.ObjectId,
      acceptedAt: Date,
    },

    isSaved: { type: Boolean, default: false },

    sharedWith: [
      {
        type: mongoose.Schema.Types.ObjectId,
        refPath: "sharedWithModel",
      },
    ],
    sharedWithModel: {
      type: String,
      enum: ["Contractor"],
      default: "Contractor",
    },

    // =============================
    // Offers
    // =============================
    offers: [
      {
        contractor: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Contractor",
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
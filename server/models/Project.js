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

    area: { type: Number },
    floors: { type: Number },
    finishingLevel: { type: String },

    status: {
      type: String,
      enum: ["open", "in_progress", "completed", "cancelled"],
      default: "open",
    },

    costEstimation: {
      materials: { type: Number, default: 0 },
      labor: { type: Number, default: 0 },
      total: { type: Number, default: 0 },
    },

    // 👇 عروض المقاولين على المشروع
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

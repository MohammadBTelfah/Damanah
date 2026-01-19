const mongoose = require("mongoose");

const contractSchema = new mongoose.Schema(
  {
    project: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Project", // ✅ تأكد أن موديل المشروع مسجل باسم "Project"
      required: true,
    },
    client: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Client", // ✅ تم التعديل من "client" إلى "Client" (أو "User" إذا كان العميل يستخدم موديل User)
      required: true,
    },
    contractor: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Contractor", // ✅ تم التعديل من "contractor" إلى "Contractor" ليطابق الموديل المسجل
      required: true,
    },

    agreedPrice: {
      type: Number,
      required: true,
    },

    durationMonths: {
      type: Number,
      default: null,
    },

    paymentTerms: {
      type: String,
      default: "",
    },

    projectDescription: {
      type: String,
      default: "",
    },

    materialsAndServices: {
      type: [String],
      default: [],
    },

    terms: {
      type: String,
      default: "",
    },

    status: {
      type: String,
      enum: ["pending", "active", "completed", "cancelled"],
      default: "active",
    },

    startDate: {
      type: Date,
      default: Date.now,
    },
    endDate: {
      type: Date,
      default: null,
    },

    contractFile: {
      type: String,
      default: null,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Contract", contractSchema);
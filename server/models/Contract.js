const mongoose = require("mongoose");

const contractSchema = new mongoose.Schema(
  {
    project: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Project",
      required: true,
    },
    client: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    contractor: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
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

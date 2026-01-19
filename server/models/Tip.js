const mongoose = require("mongoose");

const tipSchema = new mongoose.Schema(
  {
    title: { type: String, required: true },
    subtitle: { type: String, required: true },
    content: { type: String, required: true }, // النص الكامل لما يكبس عليها
    imageUrl: { type: String, required: true },
    category: { type: String, default: "General" }, // مثلا: Renovation, Legal, etc.
  },
  { timestamps: true }
);

module.exports = mongoose.model("Tip", tipSchema);
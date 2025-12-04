const mongoose = require("mongoose");

const materialSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    unit: { type: String, required: true }, // طن، م2، م3 ...
    pricePerUnit: { type: Number, required: true },

    quantityPerM2: { type: Number, required: true }, // استهلاك لكل متر مربع

    factors: {
      basic: { type: Number, default: 1 },
      medium: { type: Number, default: 1.2 },
      premium: { type: Number, default: 1.5 },
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Material", materialSchema);

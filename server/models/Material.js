const mongoose = require("mongoose");

const variantSchema = new mongoose.Schema(
  {
    key: { type: String, required: true },         // basic / medium / premium OR local / saudi / turkish ...
    label: { type: String, required: true },       // اسم يظهر بالـ UI
    pricePerUnit: { type: Number, required: true },// سعر الوحدة لهذا النوع
    quantityPerM2: { type: Number, required: true },// استهلاك/م2 لهذا النوع
  },
  { _id: false }
);

const materialSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },        // Cement / Blocks ...
    unit: { type: String, required: true },        // bag, block, m3, ton...

    // ✅ legacy (اختياري) لو بدك تضل تدعم القديم
    pricePerUnit: { type: Number },
    quantityPerM2: { type: Number },

    // ✅ الجديد: انواع متعددة
    variants: { type: [variantSchema], default: [] },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Material", materialSchema);

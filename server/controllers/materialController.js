const Material = require("../models/Material");

// =======================
// إضافة Material
// =======================
exports.createMaterial = async (req, res) => {
  try {
    const material = await Material.create(req.body);
    res.status(201).json(material);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// =======================
// جلب كل Materials
// =======================
exports.getMaterials = async (req, res) => {
  try {
    const materials = await Material.find().sort({ createdAt: -1 });
    res.json(materials);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// =======================
// جلب Material واحد
// =======================
exports.getMaterialById = async (req, res) => {
  try {
    const material = await Material.findById(req.params.id);
    if (!material)
      return res.status(404).json({ message: "Material not found" });

    res.json(material);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// =======================
// تحديث Material
// =======================
exports.updateMaterial = async (req, res) => {
  try {
    const material = await Material.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );
    res.json(material);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// =======================
// حذف Material
// =======================
exports.deleteMaterial = async (req, res) => {
  try {
    await Material.findByIdAndDelete(req.params.id);
    res.json({ message: "Material deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.bulkInsertMaterials = async (req, res) => {
  try {
    if (!Array.isArray(req.body)) {
      return res.status(400).json({ message: "Body must be an array" });
    }
    const inserted = await Material.insertMany(req.body, { ordered: false });
    res.status(201).json({ count: inserted.length, inserted });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

const Tip = require("../models/Tip");

exports.getAllTips = async (req, res) => {
  try {
    const tips = await Tip.find().sort({ createdAt: -1 });
    return res.json(tips);
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
};
// إضافة نصيحة جديدة
exports.createTip = async (req, res) => {
  try {
    const tip = new Tip(req.body);
    await tip.save();
    return res.status(201).json(tip);
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
};
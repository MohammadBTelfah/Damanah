const bcrypt = require("bcryptjs");

const Client = require("../models/Client");
const Contractor = require("../models/Contractor");
const Admin = require("../models/Admin");

const isStrongPassword = require("../utils/checkPassword");


function getModelByRole(role) {
  if (role === "client") return Client;
  if (role === "contractor") return Contractor;
  if (role === "admin") return Admin;
  return null;
}

// ✅ ensure phone unique across ALL collections (exclude current user)
async function ensurePhoneUniqueAcrossAll({ phone, role, userId }) {
  if (!phone) return;

  const queries = [
    Client.findOne({ phone, _id: { $ne: userId } }),
    Contractor.findOne({ phone, _id: { $ne: userId } }),
    Admin.findOne({ phone, _id: { $ne: userId } }),
  ];

  // ما في داعي نستثني نفس الكولكشن لأننا عاملين $ne فوق
  const [c1, c2, c3] = await Promise.all(queries);
  const exists = c1 || c2 || c3;

  if (exists) {
    const err = new Error("Phone already used");
    err.statusCode = 409;
    throw err;
  }
}

/* ================== GET ME ================== */
exports.getMe = async (req, res) => {
  try {
    const Model = getModelByRole(req.user?.role);
    if (!Model) return res.status(400).json({ message: "Invalid role" });

    const user = await Model.findById(req.user.id).select("-password");
    if (!user) return res.status(404).json({ message: "User not found" });

    return res.json({ user: { ...user.toObject(), role: req.user.role } });
  } catch (err) {
    return res.status(500).json({ message: "Server error" });
  }
};

/* ================== UPDATE ME ==================
   allowed: name, phone, profileImage
*/
exports.updateMe = async (req, res) => {
  try {
    const { name, phone } = req.body;

    const Model = getModelByRole(req.user?.role);
    if (!Model) return res.status(400).json({ message: "Invalid role" });

    const user = await Model.findById(req.user.id);
    if (!user) return res.status(404).json({ message: "User not found" });

    // ✅ phone uniqueness across all
    if (phone && phone !== user.phone) {
      await ensurePhoneUniqueAcrossAll({ phone, role: req.user.role, userId: user._id });
      user.phone = phone;
    }

    if (name) user.name = name;

    // ✅ profile image upload (multer)
    if (req.file) {
      user.profileImage = `/uploads/profiles/${req.file.filename}`;
    }

    await user.save();

    const safe = user.toObject();
    delete safe.password;

    return res.json({
      message: "Account updated",
      user: { ...safe, role: req.user.role },
    });
  } catch (err) {
    return res.status(err.statusCode || 500).json({
      message: err.message || "Server error",
    });
  }
};

/* ================== DELETE ME ================== */
exports.deleteMe = async (req, res) => {
  try {
    const Model = getModelByRole(req.user?.role);
    if (!Model) return res.status(400).json({ message: "Invalid role" });

    const user = await Model.findById(req.user.id);
    if (!user) return res.status(404).json({ message: "User not found" });

    // ✅ HARD DELETE
    await Model.findByIdAndDelete(req.user.id);

    return res.json({ message: "Account deleted successfully" });
  } catch (err) {
    return res.status(500).json({ message: "Server error" });
  }
};

/* ================== CHANGE PASSWORD ================== */
exports.changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        message: "currentPassword & newPassword required",
      });
    }

    // ✅ strong password check
    if (!isStrongPassword(newPassword)) {
      return res.status(400).json({
        message:
          "New password must be at least 8 characters long and include uppercase, lowercase, number, and special character (@$!%*?#&).",
      });
    }

    const Model = getModelByRole(req.user?.role);
    if (!Model) return res.status(400).json({ message: "Invalid role" });

    const user = await Model.findById(req.user.id);
    if (!user) return res.status(404).json({ message: "User not found" });

    const ok = await bcrypt.compare(currentPassword, user.password);
    if (!ok) {
      return res.status(401).json({
        message: "Current password is incorrect",
      });
    }

    user.password = await bcrypt.hash(newPassword, 10);
    await user.save();

    return res.json({ message: "Password changed successfully" });
  } catch (err) {
    return res.status(500).json({ message: "Server error" });
  }
};

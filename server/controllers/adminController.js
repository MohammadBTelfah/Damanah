const User = require("../models/User");

// GET /api/admin/users?role=client/contractor/admin (اختياري)
exports.getAllUsers = async (req, res) => {
  try {
    const filter = {};
    if (req.query.role) {
      filter.role = req.query.role;
    }

    const users = await User.find(filter).select("-password");
    res.json(users);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/admin/users/:id
exports.getUserById = async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select("-password");
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json(user);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// PATCH /api/admin/users/:id
exports.updateUserByAdmin = async (req, res) => {
  try {
    const updates = { ...req.body };
    delete updates.password;
    delete updates.resetPasswordToken;
    delete updates.resetPasswordExpires;

    const user = await User.findByIdAndUpdate(req.params.id, updates, {
      new: true,
    }).select("-password");

    if (!user) return res.status(404).json({ message: "User not found" });

    res.json({ message: "User updated", user });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// DELETE /api/admin/users/:id
exports.deleteUserByAdmin = async (req, res) => {
  try {
    const user = await User.findByIdAndDelete(req.params.id);
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json({ message: "User deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// PATCH /api/admin/users/:id/toggle-active
exports.toggleUserActiveStatus = async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ message: "User not found" });

    user.isActive = !user.isActive;
    await user.save();

    res.json({
      message: "User active status updated",
      isActive: user.isActive,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// =============== الهوية ===============

// GET /api/admin/users/pending-identity
exports.getPendingIdentities = async (req, res) => {
  try {
    const users = await User.find({
      identityStatus: "pending",
      identityDocument: { $ne: null },
    }).select("-password");

    res.json(users);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// PATCH /api/admin/users/:id/identity-status
// body: { status: "verified" or "rejected" }
exports.updateIdentityStatus = async (req, res) => {
  try {
    const { status } = req.body;
    if (!["verified", "rejected"].includes(status)) {
      return res.status(400).json({ message: "Invalid identity status" });
    }

    const user = await User.findByIdAndUpdate(
      req.params.id,
      { identityStatus: status },
      { new: true }
    ).select("-password");

    if (!user) return res.status(404).json({ message: "User not found" });

    res.json({ message: "Identity status updated", user });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// =============== المقاولين ===============

// GET /api/admin/contractors/pending
exports.getPendingContractors = async (req, res) => {
  try {
    const contractors = await User.find({
      role: "contractor",
      contractorStatus: "pending",
    }).select("-password");

    res.json(contractors);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// PATCH /api/admin/contractors/:id/status
// body: { status: "verified" or "rejected" }
exports.updateContractorStatus = async (req, res) => {
  try {
    const { status } = req.body;
    if (!["verified", "rejected"].includes(status)) {
      return res.status(400).json({ message: "Invalid contractor status" });
    }

    const contractor = await User.findOneAndUpdate(
      { _id: req.params.id, role: "contractor" },
      { contractorStatus: status },
      { new: true }
    ).select("-password");

    if (!contractor) {
      return res.status(404).json({ message: "Contractor not found" });
    }

    res.json({ message: "Contractor status updated", contractor });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

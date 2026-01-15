const Notification = require("../models/Notification");

// GET /api/notifications
exports.getMyNotifications = async (req, res) => {
  try {
    // protect لازم يحط req.user + role
    const userModel =
      req.user.role === "client" ? "Client" :
      req.user.role === "contractor" ? "Contractor" : "Admin";

    const list = await Notification.find({
      user: req.user._id,
      userModel,
    }).sort({ createdAt: -1 });

    res.json({ notifications: list });
  } catch (e) {
    res.status(500).json({ message: "Failed to load notifications" });
  }
};

// PATCH /api/notifications/:id/read
exports.markAsRead = async (req, res) => {
  try {
    const userModel =
      req.user.role === "client" ? "Client" :
      req.user.role === "contractor" ? "Contractor" : "Admin";

    const n = await Notification.findOneAndUpdate(
      { _id: req.params.id, user: req.user._id, userModel },
      { read: true },
      { new: true }
    );

    if (!n) return res.status(404).json({ message: "Notification not found" });
    res.json({ notification: n });
  } catch (e) {
    res.status(500).json({ message: "Failed to update notification" });
  }
};

// GET /api/notifications/unread-count
exports.unreadCount = async (req, res) => {
  try {
    const userModel =
      req.user.role === "client" ? "Client" :
      req.user.role === "contractor" ? "Contractor" : "Admin";

    const count = await Notification.countDocuments({
      user: req.user._id,
      userModel,
      read: false,
    });

    res.json({ count });
  } catch (e) {
    res.status(500).json({ message: "Failed to get count" });
  }
};

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
exports.clearAllNotifications = async (req, res) => {
  try {
    // نحذف كل الإشعارات التي تخص المستخدم المسجل دخول
    await Notification.deleteMany({ user: req.user._id });
    
    return res.json({ message: "All notifications cleared" });
  } catch (err) {
    console.error("clearAllNotifications error:", err);
    return res.status(500).json({ message: "Failed to clear notifications" });
  }
};

// ✅ 2. حذف إشعار واحد (للسحب Swipe)
exports.deleteNotification = async (req, res) => {
  try {
    const { id } = req.params;
    
    const notification = await Notification.findById(id);
    if (!notification) {
      return res.status(404).json({ message: "Notification not found" });
    }

    // تأكد أن الإشعار يخص المستخدم الحالي
    if (String(notification.user) !== String(req.user._id)) {
      return res.status(403).json({ message: "Not authorized" });
    }

    await notification.deleteOne();
    return res.json({ message: "Notification deleted" });
  } catch (err) {
    console.error("deleteNotification error:", err);
    return res.status(500).json({ message: "Failed to delete notification" });
  }
};
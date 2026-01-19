const router = require("express").Router();
const { protect } = require("../middleware/authMiddleWare");
const notificationController = require("../controllers/notificationController");

router.get("/", protect, notificationController.getMyNotifications);
router.get("/unread-count", protect, notificationController.unreadCount);
router.patch("/:id/read", protect, notificationController.markAsRead);
router.delete("/", protect, notificationController.clearAllNotifications); // حذف الكل
router.delete("/:id", protect, notificationController.deleteNotification); // حذف واحد
module.exports = router;

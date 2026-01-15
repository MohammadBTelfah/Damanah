const mongoose = require("mongoose");

const NotificationSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, required: true, refPath: "userModel" },
    userModel: { type: String, required: true, enum: ["Client", "Contractor", "Admin"] },

    title: { type: String, required: true },
    body: { type: String, default: "" },

    type: { type: String, default: "general" }, // contractor_approved, project_created...
    projectId: { type: mongoose.Schema.Types.ObjectId, ref: "Project", default: null },

    read: { type: Boolean, default: false },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Notification", NotificationSchema);

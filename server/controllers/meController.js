const bcrypt = require("bcryptjs");
const crypto = require("crypto");
const fs = require("fs");

const Client = require("../models/Client");
const Contractor = require("../models/Contractor");
const Admin = require("../models/Admin");

const isStrongPassword = require("../utils/checkPassword");

const sendEmail = require("../utils/sendEmail");

function getModelByRole(role) {
  if (role === "client") return Client;
  if (role === "contractor") return Contractor;
  if (role === "admin") return Admin;
  return null;
}

// ✅ get user id from token payload (supports multiple keys)
function getUserId(req) {
  return req.user?.id || req.user?._id || req.user?.userId || req.user?.uid;
}

// ✅ ensure phone unique across ALL collections (exclude current user)
async function ensurePhoneUniqueAcrossAll({ phone, userId }) {
  if (!phone) return;

  const queries = [
    Client.findOne({ phone, _id: { $ne: userId } }),
    Contractor.findOne({ phone, _id: { $ne: userId } }),
    Admin.findOne({ phone, _id: { $ne: userId } }),
  ];

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

    const userId = getUserId(req);
    if (!userId) {
      return res
        .status(401)
        .json({ message: "Invalid token payload (missing user id)" });
    }

    const user = await Model.findById(userId).select("-password");
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

    const userId = getUserId(req);
    if (!userId) {
      return res
        .status(401)
        .json({ message: "Invalid token payload (missing user id)" });
    }

    const user = await Model.findById(userId);
    if (!user) return res.status(404).json({ message: "User not found" });

    // ✅ phone uniqueness across all
    if (phone && phone !== user.phone) {
      await ensurePhoneUniqueAcrossAll({ phone, userId: user._id });
      user.phone = phone;
    }

    if (name) user.name = name;

    // ✅ profile image upload (multer)
    if (req.file && req.file.filename) {
      user.profileImage = `/uploads/profiles/${req.file.filename}`;

      // ✅ SAFE logs (بس لما في ملف)
      console.log("REQ.FILE.filename =>", req.file.filename);
      console.log("REQ.FILE.path =>", req.file.path);

      if (req.file.path) {
        console.log("FILE EXISTS ON DISK =>", fs.existsSync(req.file.path));
      }
    } else {
      // ✅ SAFE logs (لما ما في ملف)
      console.log("REQ.FILE => (no file uploaded)");
    }

    await user.save();

    const safe = user.toObject();
    delete safe.password;

    return res.json({
      message: "Account updated",
      user: { ...safe, role: req.user.role },
    });
  } catch (err) {
    console.error("updateMe error:", err);
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

    const userId = getUserId(req);
    if (!userId) {
      return res
        .status(401)
        .json({ message: "Invalid token payload (missing user id)" });
    }

    const user = await Model.findById(userId);
    if (!user) return res.status(404).json({ message: "User not found" });

    // ✅ HARD DELETE
    await Model.findByIdAndDelete(userId);

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

    const userId = getUserId(req);
    if (!userId) {
      return res
        .status(401)
        .json({ message: "Invalid token payload (missing user id)" });
    }

    const user = await Model.findById(userId);
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
// ================== Forget Passowrd ================== //
exports.forgotPassword = async (req, res) => {
  try {
    const { role, email } = req.body;

    // ✅ validate
    if (!role || !email) {
      return res.status(400).json({ message: "role & email required" });
    }

    const Model = getModelByRole(role);
    if (!Model) return res.status(400).json({ message: "Invalid role" });

    const emailNorm = String(email).trim().toLowerCase();
    const user = await Model.findOne({ email: emailNorm });

    // ✅ Security: same response whether user exists or not
    if (!user) {
      console.log("forgotPassword: email not found:", role, emailNorm);
      return res.json({ message: "If the email exists, an OTP was sent." });
    }

    // ✅ OTP 6 digits, never starts with 0
    const otp = String(Math.floor(100000 + Math.random() * 900000));

    // ✅ hash OTP before storing
    const otpHash = crypto.createHash("sha256").update(otp).digest("hex");

    user.resetPasswordToken = otpHash;
    user.resetPasswordExpires = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes
    await user.save();

    // ✅ send email
    try {
      const info = await sendEmail({
        to: user.email,
        subject: "Reset your password (OTP)",
        html: `
          <p>You requested to reset your password.</p>
          <p><b>Your OTP code (valid for 15 minutes):</b></p>
          <p style="font-size:26px; letter-spacing:4px;"><b>${otp}</b></p>
          <p>Open the app → enter the OTP → set a new password.</p>
        `,
      });

      console.log("✅ OTP email sent to:", user.email);
      if (info) console.log("Email info:", info);
    } catch (e) {
      console.error("❌ sendEmail failed:", e);
      return res.status(500).json({ message: "Failed to send reset email" });
    }

    return res.json({ message: "If the email exists, an OTP was sent." });
  } catch (err) {
    console.error("forgotPassword server error:", err);
    return res.status(500).json({ message: "Server error" });
  }
};


// ================== Reset Passowrd ================== //
exports.resetPassword = async (req, res) => {
  try {
    const { role, otp, newPassword } = req.body;

    // ✅ validate required
    if (!role || !otp || !newPassword) {
      return res
        .status(400)
        .json({ message: "role, otp, newPassword required" });
    }

    // ✅ validate OTP format (6 digits and not start with 0)
    const otpStr = String(otp).trim();
    if (!/^[1-9]\d{5}$/.test(otpStr)) {
      return res.status(400).json({ message: "OTP must be 6 digits (no leading 0)" });
    }

    // ✅ strong password check (same as your backend rules)
    if (!isStrongPassword(newPassword)) {
      return res.status(400).json({
        message:
          "New password must be at least 8 characters long and include uppercase, lowercase, number, and special character (@$!%*?#&).",
      });
    }

    const Model = getModelByRole(role);
    if (!Model) return res.status(400).json({ message: "Invalid role" });

    // ✅ hash otp and compare
    const otpHash = crypto.createHash("sha256").update(otpStr).digest("hex");

    const user = await Model.findOne({
      resetPasswordToken: otpHash,
      resetPasswordExpires: { $gt: new Date() },
    });

    if (!user) {
      return res.status(400).json({ message: "Invalid or expired OTP" });
    }

    // ✅ update password + clear reset fields
    user.password = await bcrypt.hash(String(newPassword), 10);
    user.resetPasswordToken = null;
    user.resetPasswordExpires = null;
    await user.save();

    return res.json({ message: "Password reset successfully" });
  } catch (err) {
    console.error("resetPassword server error:", err);
    return res.status(500).json({ message: "Server error" });
  }
};


// ================== End of File ================== //

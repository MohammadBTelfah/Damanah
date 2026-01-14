const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");

const Admin = require("../../models/Admin");
const Client = require("../../models/Client");
const Contractor = require("../../models/Contractor");

const sendEmail = require("../../utils/sendEmail");
const isStrongPassword = require("../../utils/checkPassword");

function signToken(adminId) {
  return jwt.sign({ id: adminId, role: "admin" }, process.env.JWT_SECRET, {
    expiresIn: "30d",
  });
}

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function normalizePhone(phone) {
  // اختياري: شيل المسافات فقط
  return String(phone || "").trim();
}

// ✅ prevent email/phone duplicates across ALL collections (case-insensitive emails)
async function ensureUniqueAcrossAll({ email, phone }) {
  const emailNorm = email ? normalizeEmail(email) : null;
  const phoneNorm = phone ? normalizePhone(phone) : null;

  const exists =
    (emailNorm && (await Admin.findOne({ email: emailNorm }))) ||
    (emailNorm && (await Client.findOne({ email: emailNorm }))) ||
    (emailNorm && (await Contractor.findOne({ email: emailNorm }))) ||
    (phoneNorm && (await Admin.findOne({ phone: phoneNorm }))) ||
    (phoneNorm && (await Client.findOne({ phone: phoneNorm }))) ||
    (phoneNorm && (await Contractor.findOne({ phone: phoneNorm })));

  if (exists) {
    const err = new Error("Email or phone already used");
    err.statusCode = 409;
    throw err;
  }
}

// ✅ helper: send verification email + store hashed token
async function sendVerificationEmailForAdmin(admin) {
  const emailToken = crypto.randomBytes(32).toString("hex");
  const emailTokenHash = crypto
    .createHash("sha256")
    .update(emailToken)
    .digest("hex");

  admin.emailVerified = false;
  admin.emailVerificationToken = emailTokenHash;
  admin.emailVerificationExpires = Date.now() + 24 * 60 * 60 * 1000; // 24 hours
  await admin.save();

  const verifyUrl = `${process.env.APP_URL}/admin/verify-email/${emailToken}`;

  await sendEmail({
    to: admin.email,
    subject: "Verify your Damana admin account",
    html: `
      <h2>Hello ${admin.name},</h2>
      <p>Your admin account was created.</p>
      <p>Please verify your email to activate your admin access:</p>

      <a href="${verifyUrl}"
         style="display:inline-block;padding:10px 16px;background:#1e88e5;color:#fff;text-decoration:none;border-radius:6px;font-weight:bold;">
        Verify Email
      </a>

      <p>This link is valid for 24 hours.</p>
      <p>If you didn’t request this, you can ignore this email.</p>
      <br />
      <p>— Damana Team</p>
    `,
  });
}

// ✅ ADMIN REGISTER (Protected by secret)
exports.register = async (req, res) => {
  try {
    const secretFromHeader = req.headers["x-admin-secret"];
    const { name, email, phone, password, secret: secretFromBody } = req.body;

    const secret = secretFromBody || secretFromHeader;

    if (!secret || secret !== process.env.ADMIN_REGISTER_SECRET) {
      return res.status(403).json({ message: "Forbidden" });
    }

    // ✅ uploaded profile image
    const profileImagePath = req.file
      ? `/uploads/profiles/${req.file.filename}`
      : null;

    if (!name || !email || !phone || !password) {
      return res.status(400).json({ message: "Missing required fields" });
    }

    const emailNorm = normalizeEmail(email);
    const phoneNorm = normalizePhone(phone);

    await ensureUniqueAcrossAll({ email: emailNorm, phone: phoneNorm });

    if (!isStrongPassword(password)) {
      return res.status(400).json({
        message:
          "Password must be at least 8 characters long and include uppercase, lowercase, number, and special character (@$!%*?#&).",
      });
    }

    const hashed = await bcrypt.hash(password, 10);

    const admin = await Admin.create({
      name: String(name).trim(),
      email: emailNorm,        // ✅ store normalized
      phone: phoneNorm,        // ✅ store normalized
      password: hashed,
      profileImage: profileImagePath,

      // ✅ force role
      role: "admin",

      isActive: false,
      emailVerified: false,
      emailVerificationToken: null,
      emailVerificationExpires: null,
    });

    await sendVerificationEmailForAdmin(admin);

    const token = signToken(admin._id);

    return res.status(201).json({
      message: "Admin created. Please verify email to activate.",
      token,
      role: admin.role,
      user: {
        id: admin._id,
        name: admin.name,
        email: admin.email,
        phone: admin.phone,
        profileImage: admin.profileImage,

        role: admin.role,

        isActive: admin.isActive,
        emailVerified: admin.emailVerified,
      },
    });
  } catch (err) {
    return res.status(err.statusCode || 500).json({
      message: err.message || "Server error",
    });
  }
};


// ✅ verify admin email
exports.verifyEmail = async (req, res) => {
  try {
    const { token } = req.params;
    const hashedToken = crypto.createHash("sha256").update(token).digest("hex");

    const admin = await Admin.findOne({
      emailVerificationToken: hashedToken,
      emailVerificationExpires: { $gt: Date.now() },
    });

    if (!admin) {
      return res.status(400).json({
        message: "Invalid or expired verification link (or already verified).",
        code: "VERIFY_INVALID_OR_USED",
      });
    }

    admin.emailVerified = true;
    admin.emailVerificationToken = null;
    admin.emailVerificationExpires = null;
    admin.isActive = true;

    await admin.save();

    return res.json({
      message: "Email verified successfully. You can now log in.",
      code: "VERIFIED",
    });
  } catch (err) {
    return res.status(500).json({ message: "Server error" });
  }
};

// ✅ resend admin verification email
exports.resendVerificationEmail = async (req, res) => {
  try {
    const emailNorm = normalizeEmail(req.body.email);
    if (!emailNorm) return res.status(400).json({ message: "Email is required" });

    // ✅ FIX: search by emailNorm (NOT email)
    const admin = await Admin.findOne({ email: emailNorm });
    if (!admin) return res.status(404).json({ message: "Account not found" });

    if (admin.emailVerified) {
      return res.status(400).json({ message: "Email already verified" });
    }

    await sendVerificationEmailForAdmin(admin);

    return res.json({
      message: "Verification email re-sent. Please check your inbox.",
    });
  } catch (err) {
    return res.status(500).json({ message: "Server error" });
  }
};

exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: "Email & password required" });
    }

    const emailNorm = normalizeEmail(email);

    const admin = await Admin.findOne({ email: emailNorm });
    if (!admin) return res.status(401).json({ message: "Invalid credentials" });

    const ok = await bcrypt.compare(password, admin.password);
    if (!ok) return res.status(401).json({ message: "Invalid credentials" });

    if (!admin.emailVerified) {
      return res
        .status(403)
        .json({ message: "Please verify your email before logging in." });
    }

    if (!admin.isActive) {
      return res
        .status(403)
        .json({ message: "Account is inactive. Verify email first." });
    }

    const token = signToken(admin._id);

    return res.json({
      message: "Logged in",
      token,
      role: "admin",
      user: {
        id: admin._id,
        name: admin.name,
        email: admin.email,
        phone: admin.phone,
        profileImage: admin.profileImage,
        isActive: admin.isActive,
        emailVerified: admin.emailVerified,
      },
    });
  } catch (err) {
    return res.status(500).json({ message: "Server error" });
  }
};

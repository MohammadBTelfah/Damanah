const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");

const Client = require("../../models/Client");
const Contractor = require("../../models/Contractor");
const Admin = require("../../models/Admin");

const sendEmail = require("../../utils/sendEmail");
const { extractNationalIdFromIdentity } = require("../../utils/identity_ocr");
const isStrongPassword = require("../../utils/checkPassword");

/* ===================== Helpers ===================== */

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function normalizePhone(phone) {
  return String(phone || "").trim();
}

function signToken(userId) {
  return jwt.sign({ id: userId, role: "client" }, process.env.JWT_SECRET, {
    expiresIn: "30d",
  });
}

// ✅ ensure email/phone is unique across ALL collections (case-insensitive email)
async function ensureUniqueAcrossAll({ email, phone }) {
  const emailNorm = email ? normalizeEmail(email) : null;
  const phoneNorm = phone ? normalizePhone(phone) : null;

  const exists =
    (emailNorm && (await Client.findOne({ email: emailNorm }))) ||
    (emailNorm && (await Contractor.findOne({ email: emailNorm }))) ||
    (emailNorm && (await Admin.findOne({ email: emailNorm }))) ||
    (phoneNorm && (await Client.findOne({ phone: phoneNorm }))) ||
    (phoneNorm && (await Contractor.findOne({ phone: phoneNorm }))) ||
    (phoneNorm && (await Admin.findOne({ phone: phoneNorm })));

  if (exists) {
    const err = new Error("Email or phone already used");
    err.statusCode = 409;
    throw err;
  }
}

// ✅ helper: send verification email + store hashed token
async function sendVerificationEmailForClient(client) {
  const emailToken = crypto.randomBytes(32).toString("hex");
  const emailTokenHash = crypto
    .createHash("sha256")
    .update(emailToken)
    .digest("hex");

  client.emailVerified = false;
  client.emailVerificationToken = emailTokenHash;
  client.emailVerificationExpires = Date.now() + 24 * 60 * 60 * 1000; // 24 hours
  await client.save();

  // ✅ تأكد المسار هذا يطابق صفحة verify عندك بالفرونت
const verifyUrl = `${process.env.API_URL}/api/auth/client/verify-email/${emailToken}`;

  await sendEmail({
    to: client.email,
    subject: "Verify your Damana account",
    html: `
      <h2>Hello ${client.name},</h2>
      <p>Thanks for registering with Damana.</p>
      <p>Please click the button below to verify your email:</p>

      <a href="${verifyUrl}"
         style="display:inline-block;padding:10px 16px;background:#2e7d32;color:#fff;text-decoration:none;border-radius:6px;font-weight:bold;">
        Verify Email
      </a>

      <p>This link is valid for 24 hours.</p>
      <p>If you didn’t create this account, you can ignore this email.</p>
      <br />
      <p>— Damana Team</p>
    `,
  });
}

// ✅ NEW: inform user identity is pending admin review
async function sendIdentityPendingEmailForClient(client) {
  await sendEmail({
    to: client.email,
    subject: "Your identity is pending review",
    html: `
      <h2>Hello ${client.name},</h2>
      <p>We received your identity document.</p>
      <p><b>Status:</b> Pending review ✅</p>
      <p>Please wait until an admin reviews and verifies your identity.</p>
      <p>We will notify you once it's verified.</p>
      <br />
      <p>— Damana Team</p>
    `,
  });
}

/* ===================== Controllers ===================== */

exports.register = async (req, res) => {
  try {
    let { name, email, phone, password } = req.body;

    // ✅ normalize
    name = String(name || "").trim();
    const emailNorm = normalizeEmail(email);
    const phoneNorm = normalizePhone(phone);

    // ✅ uploaded files from multer
    const profileFile = req.files?.profileImage?.[0] || null;
    const identityFile = req.files?.identityDocument?.[0] || null;

    // ✅ store paths
    const profileImagePath = profileFile
      ? `/uploads/profiles/${profileFile.filename}`
      : null;

    const identityDocumentPath = identityFile
      ? `/uploads/identity/${identityFile.filename}`
      : null;

    if (!name || !emailNorm || !phoneNorm || !password) {
      return res.status(400).json({ message: "Missing required fields" });
    }

    await ensureUniqueAcrossAll({ email: emailNorm, phone: phoneNorm });

    if (!isStrongPassword(password)) {
      return res.status(400).json({
        message:
          "Password must be at least 8 characters long and include uppercase, lowercase, number, and special character (@$!%*?#&).",
      });
    }

    const hashed = await bcrypt.hash(password, 10);

    // ================= OCR (optional) =================
    let nationalId = null;
    let nationalIdConfidence = null;
    let identityExtractedAt = null;

    if (identityDocumentPath) {
      const ocrRes = await extractNationalIdFromIdentity(identityDocumentPath);
      nationalId = ocrRes?.nationalId ?? null;
      nationalIdConfidence = ocrRes?.confidence ?? null;
      identityExtractedAt = new Date();
    }

    // ✅ إذا رفع هوية: pending
    // عدّل "none" إذا نظامك مختلف
    const identityStatus = identityDocumentPath ? "pending" : "none";

    const client = await Client.create({
      name,
      email: emailNorm, // ✅ store normalized
      phone: phoneNorm, // ✅ store normalized
      password: hashed,

      profileImage: profileImagePath,
      identityDocument: identityDocumentPath,

      nationalId,
      nationalIdConfidence,
      identityExtractedAt,

      identityStatus,

      emailVerified: false,
      emailVerificationToken: null,
      emailVerificationExpires: null,

      isActive: false,
    });

    // ✅ send verification email
    await sendVerificationEmailForClient(client);

    // ✅ if identity pending -> inform user
    if (client.identityStatus === "pending") {
      await sendIdentityPendingEmailForClient(client);
    }

    const token = signToken(client._id);

    return res.status(201).json({
      message: "Account created. Please check your email to verify your account.",
      token,
      role: "client",
      user: {
        id: client._id,
        name: client.name,
        email: client.email,
        phone: client.phone,
        profileImage: client.profileImage,
        identityDocument: client.identityDocument,
        emailVerified: client.emailVerified,
        identityStatus: client.identityStatus,
        isActive: client.isActive,
      },
    });
  } catch (err) {
    return res.status(err.statusCode || 500).json({
      message: err.message || "Server error",
    });
  }
};

exports.verifyEmail = async (req, res) => {
  try {
    const { token } = req.params;

    const hashedToken = crypto.createHash("sha256").update(token).digest("hex");

    const client = await Client.findOne({
      emailVerificationToken: hashedToken,
      emailVerificationExpires: { $gt: Date.now() },
    });

    if (!client) {
      return res.status(400).json({
        message: "Invalid or expired verification link (or already verified).",
      });
    }

    client.emailVerified = true;
    client.emailVerificationToken = null;
    client.emailVerificationExpires = null;

    // ✅ activate after email verification
    client.isActive = true;

    await client.save();

    return res.json({
      message:
        client.identityStatus === "pending"
          ? "Email verified. Your identity is pending admin review."
          : "Email verified successfully. You can now log in.",
    });
  } catch (err) {
    return res.status(500).json({ message: "Server error" });
  }
};

// ✅ resend verification email
exports.resendVerificationEmail = async (req, res) => {
  try {
    const emailNorm = normalizeEmail(req.body.email);
    if (!emailNorm) return res.status(400).json({ message: "Email is required" });

    const client = await Client.findOne({ email: emailNorm });
    if (!client) return res.status(404).json({ message: "Account not found" });

    if (client.emailVerified) {
      return res.status(400).json({ message: "Email already verified" });
    }

    await sendVerificationEmailForClient(client);

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

    if (!email || !password)
      return res.status(400).json({ message: "Email & password required" });

    const emailNorm = normalizeEmail(email);

    const client = await Client.findOne({ email: emailNorm });
    if (!client) return res.status(401).json({ message: "Invalid credentials" });

    const ok = await bcrypt.compare(password, client.password);
    if (!ok) return res.status(401).json({ message: "Invalid credentials" });

    if (!client.emailVerified) {
      return res.status(403).json({
        message: "Please verify your email before logging in.",
      });
    }

    // ✅ إذا بدك تمنع الدخول لما الهوية pending (اختياري)
    // if (client.identityStatus === "pending") {
    //   return res.status(403).json({
    //     message: "Your identity is pending admin review. Please wait.",
    //     code: "IDENTITY_PENDING",
    //   });
    // }

    const token = signToken(client._id);

    return res.json({
      message:
        client.identityStatus === "pending"
          ? "Logged in. Your identity is pending admin review."
          : "Logged in",
      token,
      role: "client",
      user: {
        id: client._id,
        name: client.name,
        email: client.email,
        phone: client.phone,

        profileImage: client.profileImage,
        identityDocument: client.identityDocument,

        isActive: client.isActive,
        emailVerified: client.emailVerified,
        identityStatus: client.identityStatus,

        nationalId: client.nationalId,
        nationalIdConfidence: client.nationalIdConfidence,
        identityExtractedAt: client.identityExtractedAt,
      },
    });
  } catch (err) {
    return res.status(500).json({ message: "Server error" });
  }
};

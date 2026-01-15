const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");

const Contractor = require("../../models/Contractor");
const Client = require("../../models/Client");
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

// ✅ الأردن: 10 أرقام ويبدأ بـ 2
function isJordanNationalId(id) {
  return typeof id === "string" && /^2\d{9}$/.test(id.trim());
}

async function ensureUniqueAcrossAll({ email, phone }) {
  const emailNorm = email ? normalizeEmail(email) : null;
  const phoneNorm = phone ? normalizePhone(phone) : null;

  const exists =
    (emailNorm && (await Contractor.findOne({ email: emailNorm }))) ||
    (emailNorm && (await Client.findOne({ email: emailNorm }))) ||
    (emailNorm && (await Admin.findOne({ email: emailNorm }))) ||
    (phoneNorm && (await Contractor.findOne({ phone: phoneNorm }))) ||
    (phoneNorm && (await Client.findOne({ phone: phoneNorm }))) ||
    (phoneNorm && (await Admin.findOne({ phone: phoneNorm })));

  if (exists) {
    const err = new Error("Email or phone already used");
    err.statusCode = 409;
    throw err;
  }
}

function signToken(userId) {
  return jwt.sign({ id: userId, role: "contractor" }, process.env.JWT_SECRET, {
    expiresIn: "30d",
  });
}

// ✅ helper: send verification email + store hashed token
async function sendVerificationEmailForContractor(contractor) {
  const emailToken = crypto.randomBytes(32).toString("hex");
  const emailTokenHash = crypto
    .createHash("sha256")
    .update(emailToken)
    .digest("hex");

  contractor.emailVerified = false;
  contractor.emailVerificationToken = emailTokenHash;
  contractor.emailVerificationExpires = Date.now() + 24 * 60 * 60 * 1000;
  await contractor.save();

  const verifyUrl = `${process.env.API_URL}/api/auth/contractor/verify-email/${emailToken}`;

  await sendEmail({
    to: contractor.email,
    subject: "Verify your Damana account",
    html: `
      <h2>Hello ${contractor.name},</h2>
      <p>Thanks for registering as a contractor in Damana.</p>
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

// ✅ identity pending message
async function sendIdentityPendingEmailForContractor(contractor) {
  await sendEmail({
    to: contractor.email,
    subject: "Your identity is pending review",
    html: `
      <h2>Hello ${contractor.name},</h2>
      <p>We received your identity document.</p>
      <p><b>Status:</b> Pending review ✅</p>
      <p>Please wait until an admin reviews and verifies your identity.</p>
      <p>We will notify you once it's verified.</p>
      <br />
      <p>— Damana Team</p>
    `,
  });
}

// ✅ contractor approval pending message
async function sendContractorPendingEmail(contractor) {
  await sendEmail({
    to: contractor.email,
    subject: "Your contractor account is pending approval",
    html: `
      <h2>Hello ${contractor.name},</h2>
      <p>We received your contractor documents.</p>
      <p><b>Status:</b> Pending admin approval ✅</p>
      <p>Please wait until an admin reviews and approves your contractor account.</p>
      <p>We will notify you once it's approved.</p>
      <br />
      <p>— Damana Team</p>
    `,
  });
}

/* ===================== Controllers ===================== */

exports.register = async (req, res) => {
  try {
    let {
      name,
      email,
      phone,
      password,
      role,
      nationalId: nationalIdInput, // ✅ يدوي من Flutter
    } = req.body;

    if (role && String(role).toLowerCase() !== "contractor") {
      return res.status(400).json({ message: "Invalid role" });
    }

    name = String(name || "").trim();
    const emailNorm = normalizeEmail(email);
    const phoneNorm = normalizePhone(phone);

    const profileFile = req.files?.profileImage?.[0] || null;
    const identityFile = req.files?.identityDocument?.[0] || null;
    const contractorDocFile = req.files?.contractorDocument?.[0] || null;

    const profileImagePath = profileFile
      ? `/uploads/profiles/${profileFile.filename}`
      : null;

    const identityDocumentPath = identityFile
      ? `/uploads/identity/${identityFile.filename}`
      : null;

    const contractorDocumentPath = contractorDocFile
      ? `/uploads/contractor_docs/${contractorDocFile.filename}`
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

    // ✅ manual nationalId (أولوية)
    const manualNationalId =
      typeof nationalIdInput === "string" && nationalIdInput.trim()
        ? nationalIdInput.trim()
        : null;

    if (manualNationalId && !isJordanNationalId(manualNationalId)) {
      return res.status(400).json({ message: "Invalid national ID format" });
    }

    // ================= OCR (optional) =================
    let nationalIdCandidate = null;
    let nationalIdConfidence = null;
    let identityRawText = null;
    let identityExtractedAt = null;

    if (identityDocumentPath) {
      const ocrRes = await extractNationalIdFromIdentity(identityDocumentPath);
      nationalIdCandidate = ocrRes?.nationalId ?? null;
      nationalIdConfidence = ocrRes?.confidence ?? null;
      identityRawText = ocrRes?.rawText ?? null;
      identityExtractedAt = new Date();
    }

    // ✅ statuses: pending only if document exists
    const identityStatus = identityDocumentPath ? "pending" : "none";
    const contractorStatus = contractorDocumentPath ? "pending" : "none";

    const contractor = await Contractor.create({
      name,
      email: emailNorm,
      phone: phoneNorm,
      password: hashed,

      role: "contractor",
      profileImage: profileImagePath,

      identityDocument: identityDocumentPath,

      // ✅ FINAL = يدوي فقط
      nationalId: manualNationalId || null,

      // ✅ OCR suggestion
      nationalIdCandidate,
      nationalIdConfidence,
      identityRawText,
      identityExtractedAt,
      identityStatus,

      contractorDocument: contractorDocumentPath,
      contractorStatus,

      emailVerified: false,
      emailVerificationToken: null,
      emailVerificationExpires: null,

      isActive: false,
    });

    await sendVerificationEmailForContractor(contractor);

    if (contractor.identityStatus === "pending") {
      await sendIdentityPendingEmailForContractor(contractor);
    }
    if (contractor.contractorStatus === "pending") {
      await sendContractorPendingEmail(contractor);
    }

    const token = signToken(contractor._id);

    return res.status(201).json({
      message:
        "Contractor account created. Please check your email to verify your account.",
      token,
      role: contractor.role,
      user: {
        id: contractor._id,
        name: contractor.name,
        email: contractor.email,
        phone: contractor.phone,

        role: contractor.role,

        profileImage: contractor.profileImage,

        identityDocument: contractor.identityDocument,
        nationalId: contractor.nationalId,
        nationalIdCandidate: contractor.nationalIdCandidate,
        nationalIdConfidence: contractor.nationalIdConfidence,
        identityExtractedAt: contractor.identityExtractedAt,
        identityStatus: contractor.identityStatus,

        contractorDocument: contractor.contractorDocument,
        contractorStatus: contractor.contractorStatus,

        emailVerified: contractor.emailVerified,
        isActive: contractor.isActive,
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

    const contractor = await Contractor.findOne({
      emailVerificationToken: hashedToken,
      emailVerificationExpires: { $gt: Date.now() },
    });

    if (!contractor) {
      return res.status(400).json({
        message: "Invalid or expired verification link (or already verified).",
      });
    }

    contractor.emailVerified = true;
    contractor.emailVerificationToken = null;
    contractor.emailVerificationExpires = null;

    // ✅ يبقى غير مفعل لحد ما الأدمن يعتمد الوثائق
    contractor.isActive = false;

    await contractor.save();

    return res.json({
      message: "Email verified. Please wait until admin reviews your documents.",
    });
  } catch (err) {
    return res.status(500).json({ message: "Server error" });
  }
};

exports.resendVerificationEmail = async (req, res) => {
  try {
    const emailNorm = normalizeEmail(req.body.email);
    if (!emailNorm) return res.status(400).json({ message: "Email is required" });

    const contractor = await Contractor.findOne({ email: emailNorm });
    if (!contractor) return res.status(404).json({ message: "Account not found" });

    if (contractor.emailVerified) {
      return res.status(400).json({ message: "Email already verified" });
    }

    await sendVerificationEmailForContractor(contractor);

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

    const contractor = await Contractor.findOne({ email: emailNorm });
    if (!contractor) return res.status(401).json({ message: "Invalid credentials" });

    const ok = await bcrypt.compare(password, contractor.password);
    if (!ok) return res.status(401).json({ message: "Invalid credentials" });

    if (!contractor.emailVerified) {
      return res.status(403).json({
        message: "Please verify your email before logging in.",
      });
    }

    if (!contractor.isActive) {
      return res.status(403).json({
        message: "Your documents are pending admin review. Please wait for approval.",
        code: "PENDING_REVIEW",
      });
    }

    const token = signToken(contractor._id);

    return res.json({
      message: "Logged in",
      token,
      role: "contractor",
      user: {
        id: contractor._id,
        name: contractor.name,
        email: contractor.email,
        phone: contractor.phone,

        profileImage: contractor.profileImage,

        isActive: contractor.isActive,
        emailVerified: contractor.emailVerified,

        identityDocument: contractor.identityDocument,
        nationalId: contractor.nationalId,
        nationalIdCandidate: contractor.nationalIdCandidate,
        nationalIdConfidence: contractor.nationalIdConfidence,
        identityExtractedAt: contractor.identityExtractedAt,
        identityStatus: contractor.identityStatus,

        contractorDocument: contractor.contractorDocument,
        contractorStatus: contractor.contractorStatus,
      },
    });
  } catch (err) {
    return res.status(500).json({ message: "Server error" });
  }
};

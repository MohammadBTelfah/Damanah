const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");

const Client = require("../../models/Client");
const Contractor = require("../../models/Contractor");
const Admin = require("../../models/Admin");

const sendEmail = require("../../utils/sendEmail");
// ✅ تحديث المسار ليشير إلى مجلد الخدمات كما أنشأناه سابقاً
const { extractNationalIdFromIdentity } = require("../../utils/identity_ocr");
const isStrongPassword = require("../../utils/checkPassword");

/* ===================== Helpers ===================== */

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function normalizePhone(phone) {
  return String(phone || "").trim();
}

// ✅ الأردن: 10 أرقام وغالباً يبدأ بـ 2
function isJordanNationalId(id) {
  return typeof id === "string" && /^2\d{9}$/.test(id.trim());
}

function signToken(userId) {
  return jwt.sign({ id: userId, role: "client" }, process.env.JWT_SECRET, {
    expiresIn: "30d",
  });
}

// ✅ Ensure email/phone is unique across ALL collections
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

// ✅ Helper: Send verification email
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
      <br />
      <p>— Damana Team</p>
    `,
  });
}

// ✅ Identity pending email
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
    let { name, email, phone, password, nationalId: nationalIdInput } = req.body;

    // ✅ 1. تطبيع البيانات
    name = String(name || "").trim();
    const emailNorm = normalizeEmail(email);
    const phoneNorm = normalizePhone(phone);

    // ✅ 2. استلام الملفات (Cloudinary)
    const profileFile = req.files?.profileImage?.[0] || null;
    const identityFile = req.files?.identityDocument?.[0] || null;

    const profileImagePath = profileFile ? profileFile.path : null;
    const identityDocumentPath = identityFile ? identityFile.path : null;

    // ✅ 3. التحقق الأساسي
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

    // ✅ 4. معالجة الرقم الوطني اليدوي
    const manualNationalId =
      typeof nationalIdInput === "string" && nationalIdInput.trim()
        ? nationalIdInput.trim()
        : null;

    if (manualNationalId && !isJordanNationalId(manualNationalId)) {
      return res.status(400).json({ message: "Invalid national ID format" });
    }

    // ================= 5. OCR Processing =================
    // تجهيز كائن البيانات الافتراضي
    let ocrData = {
      extractedName: null,
      extractedNationalId: null,
      confidence: 0,
      rawText: null,
      extractedAt: null
    };

    if (identityDocumentPath) {
      try {
        console.log("Starting OCR for:", identityDocumentPath);
        
        // استدعاء خدمة OCR
        const ocrRes = await extractNationalIdFromIdentity(identityDocumentPath);
        
        // تعبئة البيانات المستخرجة
        if (ocrRes) {
          ocrData = {
            extractedName: ocrRes.extractedName || null,
            extractedNationalId: ocrRes.nationalId || null,
            confidence: ocrRes.confidence || 0,
            rawText: ocrRes.rawText || null,
            extractedAt: new Date()
          };
        }
      } catch (ocrError) {
        console.error("OCR Error:", ocrError.message);
      }
    }

    const identityStatus = identityDocumentPath ? "pending" : "none";

    // ✅ 6. إنشاء العميل
    const client = await Client.create({
      name,
      email: emailNorm,
      phone: phoneNorm,
      password: hashed,

      role: "client",
      profileImage: profileImagePath,
      identityDocument: identityDocumentPath,

      // الرقم الوطني المعتمد (يدوياً)
      nationalId: manualNationalId || null,

      // ✅ بيانات الـ OCR مجمعة
      identityData: ocrData,

      identityStatus,

      emailVerified: false,
      isActive: false, 
    });

    // ✅ 7. إرسال الإيميلات
    await sendVerificationEmailForClient(client);

    if (client.identityStatus === "pending") {
      await sendIdentityPendingEmailForClient(client);
    }

    const token = signToken(client._id);

    return res.status(201).json({
      success: true,
      message: "Account created. Please check your email to verify your account.",
      token,
      role: client.role,
      user: {
        id: client._id,
        name: client.name,
        email: client.email,
        phone: client.phone,
        role: client.role,
        
        profileImage: client.profileImage,
        identityDocument: client.identityDocument,

        emailVerified: client.emailVerified,
        identityStatus: client.identityStatus,
        isActive: client.isActive,

        nationalId: client.nationalId,
        
        // إرجاع بيانات الـ OCR
        identityData: client.identityData 
      },
    });

  } catch (err) {
    console.error("Register Error:", err);
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

    // تفعيل الحساب بعد تأكيد الإيميل
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

// ✅ Resend verification email
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
        role: "client",

        profileImage: client.profileImage,
        identityDocument: client.identityDocument,

        isActive: client.isActive,
        emailVerified: client.emailVerified,
        identityStatus: client.identityStatus,

        nationalId: client.nationalId,

        // ✅ بيانات الـ OCR
        identityData: client.identityData 
      },
    });
  } catch (err) {
    console.error("Login Error:", err);
    return res.status(500).json({ message: "Server error" });
  }
};
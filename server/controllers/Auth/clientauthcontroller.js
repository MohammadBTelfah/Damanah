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

      <p>This link is valid for 2 hours.</p>
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
    let {
      name,
      fullName, // ✅ الاسم الإنجليزي القادم من Flutter (قابل للتعديل)
      email,
      phone,
      password,
      nationalId: nationalIdInput
    } = req.body;

    // ✅ 1. تطبيع البيانات
    name = String(name || "").trim();
    const emailNorm = normalizeEmail(email);
    const phoneNorm = normalizePhone(phone);

    // ✅ fullName القادم من Flutter (اختياري)
    const fullNameFromFlutter =
      typeof fullName === "string" && fullName.trim()
        ? fullName.trim()
        : null;

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
      extractedAt: null,
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
            extractedAt: new Date(),
          };
        }
      } catch (ocrError) {
        console.error("OCR Error:", ocrError.message);
      }
    }

    const identityStatus = identityDocumentPath ? "pending" : "none";

    // ✅ 6. تحديد الاسم النهائي الذي سيتم تخزينه
    // الأولوية: Flutter fullName (المستخدم عدّله) -> OCR extractedName -> null
    const finalFullNameFromId = fullNameFromFlutter || ocrData.extractedName || null;

    // ✅ 7. إنشاء العميل
    const client = await Client.create({
      name,
      fullNameFromId: finalFullNameFromId, // ✅ جديد

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

    // ✅ 8. إرسال الإيميلات
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

        // ✅ رجّع الاسم الإنجليزي
        fullNameFromId: client.fullNameFromId,

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
        identityData: client.identityData,
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

    // ❌ حالة الخطأ: الرابط غير صالح أو منتهي
    if (!client) {
      return res.status(400).send(`
        <!DOCTYPE html>
        <html>
        <head>
          <title>Link Expired</title>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            body { background-color: #0F261F; color: white; font-family: Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
            .card { background-color: #1B3A35; padding: 40px; border-radius: 20px; text-align: center; width: 85%; max-width: 400px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
            h1 { color: #ff6b6b; margin-bottom: 10px; }
            p { color: #ccc; line-height: 1.5; }
            .icon { font-size: 60px; margin-bottom: 20px; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="icon">⚠️</div>
            <h1>Link Invalid or Expired</h1>
            <p>This verification link is either invalid, expired, or the account has already been verified.</p>
          </div>
        </body>
        </html>
      `);
    }

    // ✅ تفعيل الحساب
    client.emailVerified = true;
    client.emailVerificationToken = null;
    client.emailVerificationExpires = null;
    client.isActive = true;

    await client.save();

    // تحديد نص الرسالة بناءً على حالة الهوية (كما كان في الكود الأصلي)
    const statusMessage = client.identityStatus === "pending"
      ? "Email verified. Your identity is pending admin review."
      : "Email verified successfully. You can now log in.";

    // ✅ حالة النجاح: إرسال صفحة خضراء
    return res.send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Email Verified</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          body { background-color: #0F261F; color: white; font-family: Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
          .card { background-color: #1B3A35; padding: 40px; border-radius: 20px; text-align: center; width: 85%; max-width: 400px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
          h1 { color: #8BE3B5; margin-bottom: 10px; }
          p { color: #e0e0e0; margin-bottom: 30px; line-height: 1.5; }
          .icon { font-size: 70px; margin-bottom: 20px; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="icon">✅</div>
          <h1>Email Verified!</h1>
          <p>${statusMessage}</p>
          <p style="font-size: 14px; opacity: 0.8;">You can now return to the app.</p>
        </div>
      </body>
      </html>
    `);

  } catch (err) {
    return res.status(500).send("<h1>Server Error</h1>");
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
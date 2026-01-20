const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");

const Contractor = require("../../models/Contractor");
const Client = require("../../models/Client");
const Admin = require("../../models/Admin");

const sendEmail = require("../../utils/sendEmail");
// ✅ استدعاء الخدمة الجديدة من المسار الصحيح
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

// ✅ helper: send verification email
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
      <p>We will notify you once it's verified.</p>
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
      <p>We will notify you once it's approved.</p>
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

    // ✅ 1. تطبيع البيانات
    name = String(name || "").trim();
    const emailNorm = normalizeEmail(email);
    const phoneNorm = normalizePhone(phone);

    // ✅ 2. استلام الملفات (Cloudinary URLs)
    const profileFile = req.files?.profileImage?.[0] || null;
    const identityFile = req.files?.identityDocument?.[0] || null;
    const contractorDocFile = req.files?.contractorDocument?.[0] || null;

    const profileImagePath = profileFile ? profileFile.path : null;
    const identityDocumentPath = identityFile ? identityFile.path : null;
    const contractorDocumentPath = contractorDocFile ? contractorDocFile.path : null;

    // ✅ 3. التحقق الأساسي
    if (!name || !emailNorm || !phoneNorm || !password) {
      return res.status(400).json({ message: "Missing required fields" });
    }

    await ensureUniqueAcrossAll({ email: emailNorm, phone: phoneNorm });

    if (!isStrongPassword(password)) {
      return res.status(400).json({
        message: "Password must be at least 8 characters long...",
      });
    }

    const hashed = await bcrypt.hash(password, 10);

    // ✅ 4. معالجة الرقم الوطني اليدوي (له الأولوية)
    const manualNationalId =
      typeof nationalIdInput === "string" && nationalIdInput.trim()
        ? nationalIdInput.trim()
        : null;

    if (manualNationalId && !isJordanNationalId(manualNationalId)) {
      return res.status(400).json({ message: "Invalid national ID format" });
    }

    // ================= 5. OCR Processing (ذكاء اصطناعي) =================
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
        const ocrRes = await extractNationalIdFromIdentity(identityDocumentPath);
        
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

    // ✅ 6. تحديد الحالات
    const identityStatus = identityDocumentPath ? "pending" : "none";
    const contractorStatus = contractorDocumentPath ? "pending" : "none";

    // ✅ 7. إنشاء المقاول
    const contractor = await Contractor.create({
      name,
      email: emailNorm,
      phone: phoneNorm,
      password: hashed,

      role: "contractor",
      profileImage: profileImagePath,

      identityDocument: identityDocumentPath,
      
      // الرقم الوطني المعتمد (يدوي)
      nationalId: manualNationalId || null,

      // ✅ بيانات الـ OCR مجمعة
      identityData: ocrData,

      identityStatus,

      contractorDocument: contractorDocumentPath,
      contractorStatus,

      emailVerified: false,
      isActive: false, // يجب أن ينتظر التفعيل
    });

    // ✅ 8. إرسال الإيميلات
    await sendVerificationEmailForContractor(contractor);

    if (contractor.identityStatus === "pending") {
      await sendIdentityPendingEmailForContractor(contractor);
    }
    if (contractor.contractorStatus === "pending") {
      await sendContractorPendingEmail(contractor);
    }

    const token = signToken(contractor._id);

    // ✅ 9. الرد
    return res.status(200).json({
      message: "Contractor account created. Please check your email.",
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
        nationalId: contractor.nationalId, // اليدوي
        
        // إرجاع كائن الـ OCR
        identityData: contractor.identityData, 
        
        identityStatus: contractor.identityStatus,

        contractorDocument: contractor.contractorDocument,
        contractorStatus: contractor.contractorStatus,

        emailVerified: contractor.emailVerified,
        isActive: contractor.isActive,
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

    const contractor = await Contractor.findOne({
      emailVerificationToken: hashedToken,
      emailVerificationExpires: { $gt: Date.now() },
    });

    // ❌ حالة الخطأ (الرابط غير صالح)
    if (!contractor) {
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

    // ✅ تحديث البيانات
    contractor.emailVerified = true;
    contractor.emailVerificationToken = null;
    contractor.emailVerificationExpires = null;
    
    // يبقى غير مفعل حتى يوافق الأدمن على الوثائق
    contractor.isActive = false; 

    await contractor.save();

    // ✅ حالة النجاح (مع رسالة خاصة بانتظار المراجعة)
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
          <p>Your email has been verified successfully.</p>
          <p style="color: #ffcc00; font-weight: bold;">Note: Your account is currently under review by the admin for document verification.</p>
          <p style="font-size: 14px; opacity: 0.8;">You will be notified once your account is active.</p>
        </div>
      </body>
      </html>
    `);

  } catch (err) {
    return res.status(500).send("<h1>Server Error</h1>");
  }
};
exports.resendVerificationEmail = async (req, res) => {
  try {
    const emailNorm = normalizeEmail(req.body.email);
    if (!emailNorm) return res.status(400).json({ message: "Email required" });

    const contractor = await Contractor.findOne({ email: emailNorm });
    if (!contractor) return res.status(404).json({ message: "Account not found" });

    if (contractor.emailVerified) {
      return res.status(400).json({ message: "Email already verified" });
    }

    await sendVerificationEmailForContractor(contractor);

    return res.json({ message: "Verification email re-sent." });
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

    // للمقاول: يجب أن يكون مفعلاً من الأدمن للدخول
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
        
        // ✅ بيانات الـ OCR مجمعة
        identityData: contractor.identityData, 
        
        identityStatus: contractor.identityStatus,

        contractorDocument: contractor.contractorDocument,
        contractorStatus: contractor.contractorStatus,
      },
    });
  } catch (err) {
    console.error("Login Error:", err);
    return res.status(500).json({ message: "Server error" });
  }
};
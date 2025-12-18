const User = require("../models/User");
const bcrypt = require("bcryptjs");
const crypto = require("crypto");
const sendEmail = require("../utils/sendEmail");
const jwt = require("jsonwebtoken");

// =============== REGISTER ===============
exports.register = async (req, res) => {
  try {
    const {
      name,
      email,
      password,
      phone,
      role,
      nationalId, // ✅ جديد
      nationalIdConfidence, // ✅ اختياري
    } = req.body;

    if (!name || !email || !password || !phone) {
      return res.status(400).json({ message: "All fields are required" });
    }

    const exists = await User.findOne({ email });
    if (exists) {
      return res.status(400).json({ message: "Email already exists" });
    }

    // قراءة الملفات المرفوعة من multer
    const files = req.files || {};

    // ✅ صورة البروفايل (اختيارية)
    const profileImagePath =
      files.profileImage && files.profileImage[0]
        ? files.profileImage[0].path
        : null;

    // الهوية
    const identityDocPath =
      files.identityDocument && files.identityDocument[0]
        ? files.identityDocument[0].path
        : null;

    // وثيقة المقاول
    const contractorDocPath =
      files.contractorDocument && files.contractorDocument[0]
        ? files.contractorDocument[0].path
        : null;

    // الهوية مطلوبة للـ client والـ contractor
    const normalizedRole = role || "client";
    if (
      (normalizedRole === "client" || normalizedRole === "contractor") &&
      !identityDocPath
    ) {
      return res.status(400).json({ message: "Identity document is required" });
    }

    // وثيقة المقاول مطلوبة فقط للـ contractor
    if (normalizedRole === "contractor" && !contractorDocPath) {
      return res
        .status(400)
        .json({ message: "Contractor document is required" });
    }

    // ✅ (اختياري لكن مهم): الرقم الوطني مطلوب إذا الهوية موجودة
    // إذا بدك تخليه إجباري 100% للـ client/contractor، خلي الشرط صارم
    if (
      (normalizedRole === "client" || normalizedRole === "contractor") &&
      !nationalId
    ) {
      return res.status(400).json({ message: "National ID is required" });
    }

    const hash = await bcrypt.hash(password, 10);

    // ✅ إنشاء المستخدم
    const user = new User({
      name,
      email,
      password: hash,
      phone,
      role: normalizedRole,

      profileImage: profileImagePath,
      identityDocument: identityDocPath,
      contractorDocument: contractorDocPath,

      // ✅ حفظ الرقم الوطني (من Flutter ML Kit)
      nationalId: nationalId ? String(nationalId).trim() : null,

      // ✅ نسبة الثقة (0..1) اختياري
      nationalIdConfidence:
        nationalIdConfidence !== undefined && nationalIdConfidence !== null && nationalIdConfidence !== ""
          ? Number(nationalIdConfidence)
          : null,

      // ✅ وقت الاستخراج
      identityExtractedAt:
        nationalId ? new Date() : null,

      // ✅ تثبيت حالات التفعيل صراحة (حتى لو default بالـ model)
      emailVerified: false,
      isActive: false,
    });

    // ✅ توليد توكن التفعيل (نخزن hash بالـ DB ونرسل raw للمستخدم)
    const emailTokenRaw = crypto.randomBytes(32).toString("hex");
    const emailTokenHashed = crypto
      .createHash("sha256")
      .update(emailTokenRaw)
      .digest("hex");

    user.emailVerificationToken = emailTokenHashed;
    user.emailVerificationExpires = Date.now() + 24 * 60 * 60 * 1000; // 24 ساعة

    await user.save();

    // ✅ رابط التفعيل
    const verifyLink = `${process.env.APP_URL}/api/auth/verify-email/${emailTokenRaw}`;

    // ✅ إرسال الإيميل
    await sendEmail({
      to: user.email,
      subject: "Verify your email",
      html: `
        <div style="font-family: Arial, sans-serif; line-height: 1.6">
          <h2>Welcome ${user.name} 👋</h2>
          <p>Please verify your email by clicking the button below:</p>
          <p>
            <a href="${verifyLink}" style="display:inline-block;padding:10px 16px;text-decoration:none;border-radius:6px;background:#2563eb;color:#fff">
              Verify Email
            </a>
          </p>
          <p>If the button doesn’t work, copy and paste this link:</p>
          <p>${verifyLink}</p>
          <p style="color:#666;font-size:12px">This link will expire in 24 hours.</p>
        </div>
      `,
    });

    return res.status(201).json({
      message:
        "Registration successful. Please check your email to verify your account.",
    });
  } catch (err) {
    console.error("Register error:", err);
    return res.status(500).json({ error: err.message });
  }
};

// =============== LOGIN ===============
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ message: "Invalid email or password" });
    }

    const match = await bcrypt.compare(password, user.password);
    if (!match) {
      return res.status(400).json({ message: "Invalid email or password" });
    }

    // 1) لازم الإيميل يكون متفعل
    if (!user.emailVerified) {
      return res.status(403).json({
        message: "Please verify your email before logging in",
      });
    }

    // 2) لازم الحساب يكون Active (إذا الأدمن سكّره)
    if (!user.isActive) {
      return res.status(403).json({ message: "Your account is deactivated" });
    }

    // 3) ✅ منع الدخول إذا الهوية لسه مش verified (للـ client و contractor)
    if ((user.role === "client" || user.role === "contractor") &&
        user.identityStatus !== "verified") {
      return res.status(403).json({
        message:
          user.identityStatus === "pending"
            ? "Your identity is not verified yet"
            : "Your identity verification was rejected",
      });
    }

    // 4) ✅ المقاول لازم كمان contractorStatus يكون verified
    if (user.role === "contractor" && user.contractorStatus !== "verified") {
      return res.status(403).json({
        message:
          user.contractorStatus === "pending"
            ? "Your contractor account is not verified yet"
            : "Your contractor verification was rejected",
      });
    }

    const token = jwt.sign(
      { id: user._id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    const userData = {
      id: user._id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      profileImage: user.profileImage,

      identityStatus: user.identityStatus,
      contractorStatus: user.contractorStatus,
      identityDocument: user.identityDocument,
      contractorDocument: user.contractorDocument,

      emailVerified: user.emailVerified,
      isActive: user.isActive,
      nationalId: user.nationalId ?? null,
    };

    return res.json({
      message: "Login successful",
      token,
      user: userData,
    });
  } catch (err) {
    console.error("Login error:", err);
    return res.status(500).json({ error: err.message });
  }
};


// =============== VERIFY EMAIL ===============
exports.verifyEmail = async (req, res) => {
  try {
    const hashedToken = crypto
      .createHash("sha256")
      .update(req.params.token)
      .digest("hex");

    const user = await User.findOne({
      emailVerificationToken: hashedToken,
      emailVerificationExpires: { $gt: Date.now() },
    });

    if (!user) {
      return res.status(400).json({ message: "Invalid or expired token" });
    }

    if (user.emailVerified) {
      return res.status(400).json({ message: "Email already verified" });
    }

    user.emailVerified = true;
    user.isActive = true;

    user.emailVerificationToken = null;
    user.emailVerificationExpires = null;

    await user.save();

    return res.json({
      message: "Email verified successfully. You can now login.",
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
};

// =============== RESEND VERIFICATION EMAIL ===============
exports.resendVerificationEmail = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ message: "Email is required" });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ message: "User not found" });
    }

    // ✅ إذا الأدمن موقف الحساب بعد ما كان مفعل
    if (user.isActive === false && user.emailVerified === true) {
      return res.status(403).json({ message: "Your account is deactivated" });
    }

    // ✅ إذا الإيميل مفعل أصلاً
    if (user.emailVerified) {
      return res.status(400).json({ message: "Email is already verified" });
    }

    // ✅ توليد توكن جديد
    const emailTokenRaw = crypto.randomBytes(32).toString("hex");
    const emailTokenHashed = crypto
      .createHash("sha256")
      .update(emailTokenRaw)
      .digest("hex");

    user.emailVerificationToken = emailTokenHashed;
    user.emailVerificationExpires = Date.now() + 24 * 60 * 60 * 1000; // 24h

    await user.save();

    const verifyLink = `${process.env.APP_URL}/api/auth/verify-email/${emailTokenRaw}`;

    await sendEmail({
      to: user.email,
      subject: "Verify Your Email",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto;">
          <h2 style="color:#333;">Verify Your Email</h2>
          <p>Hello ${user.name},</p>
          <p>Please click the link below to verify your email address:</p>
          <p><a href="${verifyLink}">${verifyLink}</a></p>
          <p style="color:#666;font-size:12px">This link will expire in 24 hours.</p>
        </div>
      `,
    });

    return res.json({
      message: "Verification email resent successfully. Please check your inbox.",
    });
  } catch (err) {
    console.error("Resend verification email error:", err);
    return res.status(500).json({ error: err.message });
  }
};

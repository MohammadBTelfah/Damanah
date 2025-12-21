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
      nationalId,
      nationalIdConfidence,
    } = req.body;

    // ✅ 1) Validate required fields (same for all roles)
    if (!name || !email || !password || !phone) {
      return res.status(400).json({ message: "All fields are required" });
    }

    // ✅ 2) normalize role + validate allowed roles
    const normalizedRole = role || "client";
    const allowedRoles = ["client", "contractor", "admin"];
    if (!allowedRoles.includes(normalizedRole)) {
      return res.status(400).json({ message: "Invalid role" });
    }

    // ✅ 3) Protect admin registration (VERY IMPORTANT)
    if (normalizedRole === "admin") {
      const secret = req.headers["x-admin-secret"];
      if (!secret || secret !== process.env.ADMIN_REGISTER_SECRET) {
        return res.status(403).json({ message: "Forbidden" });
      }
    }

    // ✅ 4) Check email uniqueness
    const exists = await User.findOne({ email });
    if (exists) {
      return res.status(400).json({ message: "Email already exists" });
    }

    // قراءة الملفات المرفوعة من multer (اختيارية)
    const files = req.files || {};

    const profileImagePath =
      files.profileImage && files.profileImage[0]
        ? files.profileImage[0].path
        : null;

    const identityDocPath =
      files.identityDocument && files.identityDocument[0]
        ? files.identityDocument[0].path
        : null;

    const contractorDocPath =
      files.contractorDocument && files.contractorDocument[0]
        ? files.contractorDocument[0].path
        : null;

    // ✅ 5) Role-specific requirements
    // الهوية مطلوبة فقط للـ client والـ contractor
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

    // الرقم الوطني مطلوب فقط للـ client والـ contractor
    if (
      (normalizedRole === "client" || normalizedRole === "contractor") &&
      (!nationalId || String(nationalId).trim().length === 0)
    ) {
      return res.status(400).json({ message: "National ID is required" });
    }

    // ✅ 6) Hash password
    const hash = await bcrypt.hash(password, 10);

    // ✅ 7) Create user (admin لا يحتاج ملفات/هوية)
    const user = new User({
      name,
      email,
      password: hash,
      phone,
      role: normalizedRole,

      // ✅ فقط للـ client/contractor (وحتى لو admin رح يكون null عادي)
      profileImage: profileImagePath,
      identityDocument:
        normalizedRole === "admin" ? null : identityDocPath,
      contractorDocument:
        normalizedRole === "contractor" ? contractorDocPath : null,

      // ✅ nationalId فقط للـ client/contractor
      nationalId:
        normalizedRole === "admin" ? null : String(nationalId || "").trim() || null,

      nationalIdConfidence:
        normalizedRole === "admin"
          ? null
          : (nationalIdConfidence !== undefined &&
             nationalIdConfidence !== null &&
             nationalIdConfidence !== "")
            ? Number(nationalIdConfidence)
            : null,

      identityExtractedAt:
        normalizedRole === "admin"
          ? null
          : (nationalId ? new Date() : null),

      // ✅ تفعيل ايميل للجميع (حتى admin)
      emailVerified: false,

      // ✅ الحساب مش active إلا بعد تفعيل الإيميل
      isActive: false,
    });

    // ✅ 8) Create verification token
    const emailTokenRaw = crypto.randomBytes(32).toString("hex");
    const emailTokenHashed = crypto
      .createHash("sha256")
      .update(emailTokenRaw)
      .digest("hex");

    user.emailVerificationToken = emailTokenHashed;
    user.emailVerificationExpires = Date.now() + 24 * 60 * 60 * 1000;

    await user.save();

    // ✅ 9) Send verify email
    const verifyLink = `${process.env.APP_URL}/api/auth/verify-email/${emailTokenRaw}`;

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

const User = require("../models/User");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

// =============== REGISTER ===============
exports.register = async (req, res) => {
  try {
    const { name, email, password, phone, role } = req.body;

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
    if ((role === "client" || role === "contractor") && !identityDocPath) {
      return res
        .status(400)
        .json({ message: "Identity document is required" });
    }

    // وثيقة المقاول مطلوبة فقط للـ contractor
    if (role === "contractor" && !contractorDocPath) {
      return res
        .status(400)
        .json({ message: "Contractor document is required" });
    }

    const hash = await bcrypt.hash(password, 10);

    const user = new User({
      name,
      email,
      password: hash,
      phone,
      role: role || "client",

      // ✅ الجديد
      profileImage: profileImagePath,

      identityDocument: identityDocPath,
      contractorDocument: contractorDocPath,
      // identityStatus = pending by default
      // contractorStatus = pending by default
    });

    await user.save();

    const userData = {
      id: user._id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      role: user.role,

      // ✅ الجديد
      profileImage: user.profileImage,

      identityStatus: user.identityStatus,
      contractorStatus: user.contractorStatus,
      identityDocument: user.identityDocument,
      contractorDocument: user.contractorDocument,
      isActive: user.isActive,
    };

    res.status(201).json({ message: "User registered", user: userData });
  } catch (err) {
    console.error("Register error:", err);
    res.status(500).json({ error: err.message });
  }
};

// =============== LOGIN ===============
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email });
    if (!user) {
      return res
        .status(400)
        .json({ message: "Invalid email or password" });
    }

    if (!user.isActive) {
      return res
        .status(403)
        .json({ message: "Your account is deactivated" });
    }

    // منع المقاول غير الموثّق من الدخول
    if (user.role === "contractor" && user.contractorStatus !== "verified") {
      return res.status(403).json({
        message:
          user.contractorStatus === "pending"
            ? "Your contractor account is not verified yet"
            : "Your contractor verification was rejected",
      });
    }

    const match = await bcrypt.compare(password, user.password);
    if (!match) {
      return res
        .status(400)
        .json({ message: "Invalid email or password" });
    }

    const token = jwt.sign(
      { id: user._id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    // ✅ رجّع كل البيانات اللي يحتاجها الفرونت
    const userData = {
      id: user._id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      role: user.role,

      // ✅ الجديد
      profileImage: user.profileImage,

      identityStatus: user.identityStatus,
      contractorStatus: user.contractorStatus,
      identityDocument: user.identityDocument,
      contractorDocument: user.contractorDocument,
      isActive: user.isActive,
    };

    res.json({
      message: "Login successful",
      token,
      user: userData,
    });
  } catch (err) {
    console.error("Login error:", err);
    res.status(500).json({ error: err.message });
  }
};

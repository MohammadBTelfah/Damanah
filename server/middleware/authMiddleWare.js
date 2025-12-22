const jwt = require("jsonwebtoken");

const Client = require("../models/Client");
const Contractor = require("../models/Contractor");
const Admin = require("../models/Admin");

function getModelByRole(role) {
  if (role === "client") return Client;
  if (role === "contractor") return Contractor;
  if (role === "admin") return Admin;
  return null;
}

exports.protect = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization || "";
    const token = authHeader.startsWith("Bearer ")
      ? authHeader.split(" ")[1]
      : null;

    if (!token) {
      return res.status(401).json({ message: "No token provided" });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    if (!decoded?.role || !decoded?.id) {
      return res.status(401).json({ message: "Invalid token payload" });
    }

    const Model = getModelByRole(decoded.role);
    if (!Model) {
      return res.status(401).json({ message: "Invalid role in token" });
    }

    const user = await Model.findById(decoded.id).select("-password");
    if (!user) {
      return res.status(401).json({ message: "User not found" });
    }

    // ✅ نخلي role موجود حتى لو مش مخزن بالـ DB
    req.user = { ...user.toObject(), role: decoded.role };

    next();
  } catch (err) {
    console.error("Auth error:", err.message);
    return res.status(401).json({ message: "Invalid or expired token" });
  }
};

// ✅ NEW: require verified email (works for all roles if field exists)
exports.verifiedOnly = (req, res, next) => {
  // إذا الحقل غير موجود بالموديل (قديم) خلّيه يمر
  if (typeof req.user?.emailVerified === "boolean" && !req.user.emailVerified) {
    return res.status(403).json({ message: "Please verify your email first" });
  }
  next();
};

// ✅ NEW: require active account (works for all roles if field exists)
exports.activeOnly = (req, res, next) => {
  if (typeof req.user?.isActive === "boolean" && !req.user.isActive) {
    return res.status(403).json({ message: "Account is inactive" });
  }
  next();
};

// ✅ convenience
exports.verifiedAndActive = (req, res, next) => {
  if (typeof req.user?.emailVerified === "boolean" && !req.user.emailVerified) {
    return res.status(403).json({ message: "Please verify your email first" });
  }
  if (typeof req.user?.isActive === "boolean" && !req.user.isActive) {
    return res.status(403).json({ message: "Account is inactive" });
  }
  next();
};

exports.clientOnly = (req, res, next) => {
  if (req.user?.role !== "client") {
    return res.status(403).json({ message: "Clients only" });
  }
  next();
};

exports.contractorOnly = (req, res, next) => {
  if (req.user?.role !== "contractor") {
    return res.status(403).json({ message: "Contractors only" });
  }
  next();
};

exports.adminOnly = (req, res, next) => {
  if (req.user?.role !== "admin") {
    return res.status(403).json({ message: "Admins only" });
  }
  next();
};

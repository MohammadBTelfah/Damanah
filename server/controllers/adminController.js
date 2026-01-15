const Client = require("../models/Client");
const Contractor = require("../models/Contractor");
const Admin = require("../models/Admin");
const sendEmail = require("../utils/sendEmail");

/* ===================== Helpers ===================== */

function getBaseUrl(req) {
  return `${req.protocol}://${req.get("host")}`;
}

function toPublicUrls(doc, baseUrl) {
  const obj = doc.toObject();

  return {
    ...obj,
    profileImageUrl: obj.profileImage ? `${baseUrl}${obj.profileImage}` : null,
    identityDocumentUrl: obj.identityDocument ? `${baseUrl}${obj.identityDocument}` : null,
    contractorDocumentUrl: obj.contractorDocument ? `${baseUrl}${obj.contractorDocument}` : null,
  };
}

function getModelByRole(role) {
  if (role === "client") return Client;
  if (role === "contractor") return Contractor;
  if (role === "admin") return Admin;
  return null;
}

// ✅ ensure email/phone is unique across ALL collections (excluding current user)
async function ensureUniqueAcrossAllExcept({ email, phone, excludeId }) {
  const queries = [];

  if (email) {
    queries.push(Client.findOne({ email, _id: { $ne: excludeId } }));
    queries.push(Contractor.findOne({ email, _id: { $ne: excludeId } }));
    queries.push(Admin.findOne({ email, _id: { $ne: excludeId } }));
  }

  if (phone) {
    queries.push(Client.findOne({ phone, _id: { $ne: excludeId } }));
    queries.push(Contractor.findOne({ phone, _id: { $ne: excludeId } }));
    queries.push(Admin.findOne({ phone, _id: { $ne: excludeId } }));
  }

  const results = await Promise.all(queries);
  const exists = results.find(Boolean);

  if (exists) {
    const err = new Error("Email or phone already used");
    err.statusCode = 409;
    throw err;
  }
}

/* ===================== Emails ===================== */

async function sendIdentityApprovedEmail(user) {
  await sendEmail({
    to: user.email,
    subject: "Your identity has been approved ✅",
    html: `
      <h2>Hello ${user.name},</h2>
      <p>Your identity has been <b>approved</b> ✅</p>
      <p>You can now use all features that require a verified identity.</p>
      <br />
      <p>— Damana Team</p>
    `,
  });
}

async function sendIdentityRejectedEmail(user) {
  await sendEmail({
    to: user.email,
    subject: "Your identity verification was rejected ❌",
    html: `
      <h2>Hello ${user.name},</h2>
      <p>Your identity verification was <b>rejected</b> ❌</p>
      <p>Please upload a clearer identity document and try again.</p>
      <br />
      <p>— Damana Team</p>
    `,
  });
}

async function sendContractorApprovedEmail(user) {
  await sendEmail({
    to: user.email,
    subject: "Your contractor account has been approved ✅",
    html: `
      <h2>Hello ${user.name},</h2>
      <p>Your contractor documents have been <b>approved</b> ✅</p>
      <p>You can now use your contractor dashboard.</p>
      <br />
      <p>— Damana Team</p>
    `,
  });
}

async function sendContractorRejectedEmail(user) {
  await sendEmail({
    to: user.email,
    subject: "Your contractor verification was rejected ❌",
    html: `
      <h2>Hello ${user.name},</h2>
      <p>Your contractor verification was <b>rejected</b> ❌</p>
      <p>Please upload valid/clear contractor documents and try again.</p>
      <br />
      <p>— Damana Team</p>
    `,
  });
}

/* ===================== Activation Logic ===================== */

function computeContractorActive(contractor) {
  // ✅ active only if email verified + statuses ok
  const identityOk =
    contractor.identityStatus === "verified" || contractor.identityStatus === "none";
  const contractorOk =
    contractor.contractorStatus === "verified" || contractor.contractorStatus === "none";

  return contractor.emailVerified === true && identityOk && contractorOk;
}

/* ===================== Users ===================== */

// GET /api/admin/users?role=client/contractor/admin (اختياري)
exports.getAllUsers = async (req, res) => {
  try {
    const role = req.query.role;

    if (role) {
      const Model = getModelByRole(role);
      if (!Model) return res.status(400).json({ message: "Invalid role" });

      const users = await Model.find({}).select("-password");
      const baseUrl = getBaseUrl(req);

      const mapped = users.map((u) => {
        const out = toPublicUrls(u, baseUrl);
        out.role = role;
        return out;
      });

      return res.json(mapped);
    }

    const [clients, contractors, admins] = await Promise.all([
      Client.find({}).select("-password"),
      Contractor.find({}).select("-password"),
      Admin.find({}).select("-password"),
    ]);

    const baseUrl = getBaseUrl(req);

    const result = [
      ...clients.map((u) => ({ ...toPublicUrls(u, baseUrl), role: "client" })),
      ...contractors.map((u) => ({ ...toPublicUrls(u, baseUrl), role: "contractor" })),
      ...admins.map((u) => ({ ...toPublicUrls(u, baseUrl), role: "admin" })),
    ];

    return res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/admin/users/:role/:id
exports.getUserById = async (req, res) => {
  try {
    const { role, id } = req.params;

    const Model = getModelByRole(role);
    if (!Model) return res.status(400).json({ message: "Invalid role" });

    const user = await Model.findById(id).select("-password");
    if (!user) return res.status(404).json({ message: "User not found" });

    const baseUrl = getBaseUrl(req);
    const out = toPublicUrls(user, baseUrl);
    out.role = role;

    res.json(out);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// PATCH /api/admin/users/:role/:id
exports.updateUserByAdmin = async (req, res) => {
  try {
    const { role, id } = req.params;
    const Model = getModelByRole(role);
    if (!Model) return res.status(400).json({ message: "Invalid role" });

    const updates = { ...req.body };

    // ✅ ممنوعات عامة
    delete updates.password;
    delete updates.resetPasswordToken;
    delete updates.resetPasswordExpires;

    // ✅ ممنوع العبث بالتفعيل/التوكن
    delete updates.emailVerified;
    delete updates.emailVerificationToken;
    delete updates.emailVerificationExpires;

    // ✅ ممنوعات عامة أخرى
    delete updates._id;
    delete updates.role;

    // ✅ الأدمن ما عنده هوية/مقاول
    if (role === "admin") {
      delete updates.identityDocument;
      delete updates.identityStatus;
      delete updates.nationalId;
      delete updates.nationalIdConfidence;
      delete updates.identityExtractedAt;
      delete updates.contractorDocument;
      delete updates.contractorStatus;
    }

    // ✅ العميل ما عنده حقول مقاول
    if (role === "client") {
      delete updates.contractorDocument;
      delete updates.contractorStatus;
    }

    // ✅ تحقق uniqueness عند تعديل email/phone
    if (updates.email || updates.phone) {
      await ensureUniqueAcrossAllExcept({
        email: updates.email,
        phone: updates.phone,
        excludeId: id,
      });
    }

    const user = await Model.findByIdAndUpdate(id, updates, { new: true }).select(
      "-password"
    );
    if (!user) return res.status(404).json({ message: "User not found" });

    const baseUrl = getBaseUrl(req);
    const out = toPublicUrls(user, baseUrl);
    out.role = role;

    res.json({ message: "User updated", user: out });
  } catch (err) {
    res.status(err.statusCode || 500).json({ error: err.message });
  }
};

// DELETE /api/admin/users/:role/:id
exports.deleteUserByAdmin = async (req, res) => {
  try {
    const { role, id } = req.params;
    const Model = getModelByRole(role);
    if (!Model) return res.status(400).json({ message: "Invalid role" });

    if (role === "admin" && req.user?.id?.toString() === id.toString()) {
      return res
        .status(400)
        .json({ message: "You cannot delete your own admin account" });
    }

    const user = await Model.findByIdAndDelete(id);
    if (!user) return res.status(404).json({ message: "User not found" });

    res.json({ message: "User deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// PATCH /api/admin/users/:role/:id/toggle-active
exports.toggleUserActiveStatus = async (req, res) => {
  try {
    const { role, id } = req.params;
    const Model = getModelByRole(role);
    if (!Model) return res.status(400).json({ message: "Invalid role" });

    if (role === "admin" && req.user?.id?.toString() === id.toString()) {
      return res.status(400).json({ message: "You cannot disable your own admin account" });
    }

    const user = await Model.findById(id);
    if (!user) return res.status(404).json({ message: "User not found" });

    user.isActive = !user.isActive;
    await user.save();

    const baseUrl = getBaseUrl(req);
    const out = toPublicUrls(user, baseUrl);
    out.role = role;

    res.json({ message: "User active status updated", user: out });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

/* ===================== Identity ===================== */

// GET /api/admin/users/pending-identity
exports.getPendingIdentities = async (req, res) => {
  try {
    const [clients, contractors] = await Promise.all([
      Client.find({
        identityStatus: "pending",
        identityDocument: { $ne: null },
      }).select("-password"),

      Contractor.find({
        identityStatus: "pending",
        identityDocument: { $ne: null },
      }).select("-password"),
    ]);

    const baseUrl = getBaseUrl(req);

    const mapped = [
      ...clients.map((u) => ({ ...toPublicUrls(u, baseUrl), role: "client" })),
      ...contractors.map((u) => ({ ...toPublicUrls(u, baseUrl), role: "contractor" })),
    ];

    res.json(mapped);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// PATCH /api/admin/users/:role/:id/identity-status
// body: { status: "verified" or "rejected", nationalId?: "..." }
exports.updateIdentityStatus = async (req, res) => {
  try {
    const { role, id } = req.params;

    if (!["client", "contractor"].includes(role)) {
      return res.status(400).json({
        message: "Identity exists only for client/contractor",
      });
    }

    const { status, nationalId } = req.body;
    if (!["verified", "rejected"].includes(status)) {
      return res.status(400).json({ message: "Invalid identity status" });
    }

    const Model = role === "client" ? Client : Contractor;

    const user = await Model.findById(id).select("-password");
    if (!user) return res.status(404).json({ message: "User not found" });

    const prevStatus = user.identityStatus;

    user.identityStatus = status;

    if (typeof nationalId === "string" && nationalId.trim().length > 0) {
      user.nationalId = nationalId.trim();
      user.identityExtractedAt = new Date();
      user.nationalIdConfidence = null;
    }

    // ✅ للمقاول: فعّل فقط إذا كل الشروط تمام
    if (role === "contractor") {
      user.isActive = computeContractorActive(user);
    }

    await user.save();

    // ✅ Send email only if status changed
    if (prevStatus !== status) {
      if (status === "verified") await sendIdentityApprovedEmail(user);
      if (status === "rejected") await sendIdentityRejectedEmail(user);
    }

    return res.json({ message: "Identity status updated", user });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
};

// GET /api/admin/users/:role/:id/identity
exports.getUserIdentityDetails = async (req, res) => {
  try {
    const { role, id } = req.params;

    if (!["client", "contractor"].includes(role)) {
      return res.status(400).json({ message: "Identity exists only for client/contractor" });
    }

    const Model = role === "client" ? Client : Contractor;

    const user = await Model.findById(id).select("-password");
    if (!user) return res.status(404).json({ message: "User not found" });

    const baseUrl = getBaseUrl(req);
    const out = toPublicUrls(user, baseUrl);
    out.role = role;

    res.json(out);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

/* ===================== Contractors ===================== */

// GET /api/admin/contractors/pending
exports.getPendingContractors = async (req, res) => {
  try {
    const contractors = await Contractor.find({
      contractorStatus: "pending",
    }).select("-password");

    const baseUrl = getBaseUrl(req);
    const mapped = contractors.map((u) => ({
      ...toPublicUrls(u, baseUrl),
      role: "contractor",
    }));

    res.json(mapped);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// PATCH /api/admin/contractors/:id/status
// body: { status: "verified" or "rejected" }
exports.updateContractorStatus = async (req, res) => {
  try {
    const { status } = req.body;
    if (!["verified", "rejected"].includes(status)) {
      return res.status(400).json({ message: "Invalid contractor status" });
    }

    const contractor = await Contractor.findById(req.params.id).select("-password");
    if (!contractor) {
      return res.status(404).json({ message: "Contractor not found" });
    }

    const prev = contractor.contractorStatus;

    contractor.contractorStatus = status;

    // ✅ حساب isActive الصحيح للمقاول
    contractor.isActive = computeContractorActive(contractor);

    await contractor.save();

    // ✅ Send email only if status changed
    if (prev !== status) {
      if (status === "verified") await sendContractorApprovedEmail(contractor);
      if (status === "rejected") await sendContractorRejectedEmail(contractor);
    }

    const baseUrl = getBaseUrl(req);
    const out = toPublicUrls(contractor, baseUrl);
    out.role = "contractor";

    res.json({ message: "Contractor status updated", contractor: out });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

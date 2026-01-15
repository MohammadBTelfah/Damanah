const Project = require("../models/Project");
const Contract = require("../models/Contract");
const Contractor = require("../models/Contractor");
const Notification = require("../models/Notification");

const { generateBoqForProject } = require("../utils/boq");
const { analyzeFloorPlanImage } = require("../utils/plan_vision");
const mongoose = require("mongoose");

// =======================
// Helpers
// =======================
function toInt(v) {
  if (v === null || v === undefined || v === "") return null;
  const n = Number(v);
  if (!Number.isFinite(n)) return null;
  return Math.trunc(n);
}

function toDouble(v) {
  if (v === null || v === undefined || v === "") return null;
  const n = Number(v);
  if (!Number.isFinite(n)) return null;
  return n;
}

function sanitizePlanAnalysis(planAnalysis) {
  if (!planAnalysis || typeof planAnalysis !== "object") return undefined;
  const a = { ...planAnalysis };
  if (a.totalArea !== undefined) {
    const d = toDouble(a.totalArea);
    if (d !== null) a.totalArea = d;
  }
  if (a.floors !== undefined) {
    const n = toInt(a.floors);
    if (n !== null) a.floors = n;
  }
  if (Array.isArray(a.rooms)) {
    a.roomsDetails = a.rooms;
    a.rooms = a.rooms.length;
  } else if (a.rooms && typeof a.rooms === "object") {
    a.roomsDetails = [a.rooms];
    a.rooms = 1;
  } else if (a.rooms !== undefined) {
    const n = toInt(a.rooms);
    if (n !== null) a.rooms = n;
  }
  if (Array.isArray(a.bathrooms)) {
    a.bathroomsDetails = a.bathrooms;
    a.bathrooms = a.bathrooms.length;
  } else if (a.bathrooms && typeof a.bathrooms === "object") {
    a.bathroomsDetails = [a.bathrooms];
    a.bathrooms = 1;
  } else if (a.bathrooms !== undefined) {
    const n = toInt(a.bathrooms);
    if (n !== null) a.bathrooms = n;
  }
  return a;
}

function getBaseUrl(req) {
  return `${req.protocol}://${req.get("host")}`;
}

// =======================
// ✅ قائمة المقاولين المتاحين (للـ client)
// =======================
exports.getAvailableContractors = async (req, res) => {
  try {
    const contractors = await Contractor.find({
      emailVerified: true,
      contractorStatus: "verified",
      isActive: true,
    }).select("_id name email phone profileImage");

    const baseUrl = getBaseUrl(req);
    const list = contractors.map((c) => {
      const obj = c.toObject();
      return {
        ...obj,
        profileImageUrl: obj.profileImage
          ? (String(obj.profileImage).startsWith("http")
              ? obj.profileImage
              : `${baseUrl}${obj.profileImage}`)
          : null,
      };
    });
    return res.json(list);
  } catch (err) {
    console.error("getAvailableContractors error:", err);
    return res
      .status(500)
      .json({ message: "Failed to load contractors", error: err.message });
  }
};

// =======================
// إنشاء مشروع جديد
// =======================
exports.createProject = async (req, res) => {
  try {
    const {
      title,
      description,
      location,
      area,
      floors,
      finishingLevel,
      buildingType,
      planAnalysis,
    } = req.body;

    if (!title || String(title).trim().length === 0) {
      return res.status(400).json({ message: "Title is required" });
    }

    const areaNum = area === null || area === undefined || area === "" ? null : Number(area);
    const floorsNum = floors === null || floors === undefined || floors === "" ? null : Number(floors);

    if (areaNum !== null && (!Number.isFinite(areaNum) || areaNum <= 0)) {
      return res.status(400).json({ message: "Invalid area" });
    }
    if (floorsNum !== null && (!Number.isFinite(floorsNum) || floorsNum <= 0)) {
      return res.status(400).json({ message: "Invalid floors" });
    }

    const level = String(finishingLevel || "basic").toLowerCase().trim();
    const allowedLevels = ["basic", "medium", "premium"];
    const safeLevel = allowedLevels.includes(level) ? level : "basic";

    const bt = String(buildingType || "apartment").toLowerCase().trim();
    const allowedTypes = ["apartment", "villa", "commercial", "house"];
    let safeBuildingType = allowedTypes.includes(bt) ? bt : "apartment";
    if (safeBuildingType === "house") safeBuildingType = "villa";

    const safePlanAnalysis = typeof sanitizePlanAnalysis === "function"
        ? sanitizePlanAnalysis(planAnalysis)
        : planAnalysis;

    const project = new Project({
      owner: req.user._id,
      title: String(title).trim(),
      description: description ? String(description).trim() : "",
      location: location ? String(location).trim() : "",
      area: areaNum,
      floors: floorsNum,
      finishingLevel: safeLevel,
      buildingType: safeBuildingType,
      planAnalysis: safePlanAnalysis,
      status: "draft", // Start as draft until published
    });

    await project.save();

    return res.status(201).json({
      message: "Project created successfully",
      project,
    });
  } catch (err) {
    console.error("createProject error:", err);
    return res.status(500).json({ error: err.message });
  }
};

// =======================
// 🔥 NEW: Publish Project to All Contractors
// PATCH /api/projects/:projectId/publish
// =======================
exports.publishProject = async (req, res) => {
  try {
    const { projectId } = req.params;

    const project = await Project.findById(projectId);
    if (!project) return res.status(404).json({ message: "Project not found" });

    if (String(project.owner) !== String(req.user._id)) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    // لجعله متاحاً للجميع: الحالة open والمصفوفة sharedWith فارغة
    project.status = "open";
    project.sharedWith = []; 
    project.sharedWithModel = undefined; // reset
    project.isSaved = true; // Ensure it's marked as saved

    await project.save();

    // اختياري: إرسال إشعار للمقاولين (يتطلب منطق إضافي لجلب جميع المقاولين وإرسال إشعارات لهم)
    // حالياً نكتفي بجعل المشروع متاحاً في القائمة

    return res.json({ message: "Project published to all contractors", project });
  } catch (err) {
    console.error("publishProject error:", err);
    return res.status(500).json({ message: "Publish failed", error: err.message });
  }
};

// =======================
// Contractor - Available Projects
// =======================
exports.getAvailableProjectsForContractor = async (req, res) => {
  try {
    const contractorId = req.user._id;

    const projects = await Project.find({
      status: "open",
      contractor: null,
      $or: [
        { sharedWith: contractorId },
        { sharedWith: { $exists: false } },
        { sharedWith: { $size: 0 } }, // This picks up published projects
      ],
    })
      .populate("owner", "name email")
      .sort({ createdAt: -1 });

    return res.json({ projects });
  } catch (err) {
    console.error("getAvailableProjectsForContractor error:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

// =======================
// Contractor - My Projects
// =======================
exports.getMyProjectsForContractor = async (req, res) => {
  try {
    const contractorId = req.user._id;
    const projects = await Project.find({
      contractor: contractorId,
    })
      .populate("owner", "name email")
      .sort({ createdAt: -1 });

    return res.json({ projects });
  } catch (err) {
    console.error("getMyProjectsForContractor error:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

// =======================
// مشاريعي (client)
// =======================
exports.getMyProjects = async (req, res) => {
  try {
    const projects = await Project.find({ owner: req.user._id })
      .populate("owner", "name email")
      .populate("contractor", "name email")
      .sort({ createdAt: -1 });

    return res.json(projects);
  } catch (err) {
    console.error("getMyProjects error:", err);
    return res.status(500).json({ error: err.message });
  }
};

// =======================
// المشاريع المفتوحة
// =======================
exports.getOpenProjects = async (req, res) => {
  try {
    const projects = await Project.find({
      status: "open",
      contractor: null,
    })
      .populate("owner", "name email")
      .populate("contractor", "name email")
      .sort({ createdAt: -1 });

    return res.json(projects);
  } catch (err) {
    console.error("getOpenProjects error:", err);
    return res.status(500).json({ error: err.message });
  }
};

// =======================
// مشروع معيّن
// =======================
exports.getProjectById = async (req, res) => {
  try {
    const { projectId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(projectId)) {
      return res.status(404).json({ message: "Project not found" });
    }
    const project = await Project.findById(projectId)
      .populate("owner", "name email")
      .populate("contractor", "_id name email phone profileImage contractorStatus isActive")
      .populate("offers.contractor", "_id name email phone profileImage");

    if (!project) return res.status(404).json({ message: "Project not found" });
    return res.json(project);
  } catch (err) {
    console.error("getProjectById error:", err);
    return res.status(500).json({ error: err.message });
  }
};

// =======================
// إنشاء عرض (Contractor)
// =======================
exports.createOffer = async (req, res) => {
  try {
    const { price, message } = req.body;
    const { projectId } = req.params;

    if (!price) return res.status(400).json({ message: "Price is required" });

    const project = await Project.findById(projectId);
    if (!project) return res.status(404).json({ message: "Project not found" });

    if (project.status !== "open") {
      return res.status(400).json({ message: "Offers are only allowed on open projects" });
    }

    const exists = project.offers.find(
      (o) => o.contractor.toString() === req.user._id.toString()
    );
    if (exists) {
      return res.status(400).json({ message: "You already submitted an offer for this project" });
    }

    project.offers.push({
      contractor: req.user._id,
      price,
      message,
    });

    await project.save();

    try {
      await Notification.create({
        user: project.owner,
        userModel: "Client",
        title: "New offer received",
        body: `A contractor submitted an offer on "${project.title}".`,
        type: "offer_created",
        projectId: project._id,
        read: false,
      });
    } catch (e) {
      console.error("notification offer_created failed:", e.message);
    }

    return res.status(201).json({ message: "Offer submitted", project });
  } catch (err) {
    console.error("createOffer error:", err);
    return res.status(500).json({ error: err.message });
  }
};

// =======================
// جلب العروض
// =======================
exports.getProjectOffers = async (req, res) => {
  try {
    const { projectId } = req.params;
    const project = await Project.findById(projectId)
      .populate("offers.contractor", "name email phone")
      .populate("owner", "name email");

    if (!project) return res.status(404).json({ message: "Project not found" });
    if (project.owner._id.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not owner of this project" });
    }
    return res.json(project.offers);
  } catch (err) {
    console.error("getProjectOffers error:", err);
    return res.status(500).json({ error: err.message });
  }
};

// =======================
// قبول العرض
// =======================
exports.acceptOffer = async (req, res) => {
  try {
    const { projectId, offerId } = req.params;

    const project = await Project.findById(projectId);
    if (!project) return res.status(404).json({ message: "Project not found" });
    if (project.owner.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    const offer = project.offers.id(offerId);
    if (!offer) return res.status(404).json({ message: "Offer not found" });

    project.contractor = offer.contractor;
    project.status = "in_progress";

    project.offers.forEach((o) => {
      o.status = o._id.toString() === offerId.toString() ? "accepted" : "rejected";
    });

    await project.save();

    try {
      await Notification.create({
        user: offer.contractor,
        userModel: "Contractor",
        title: "Offer accepted",
        body: `Your offer was accepted for "${project.title}".`,
        type: "offer_accepted",
        projectId: project._id,
        read: false,
      });
    } catch (e) {
      console.error("notification offer_accepted failed:", e.message);
    }

    const contract = await Contract.create({
      project: project._id,
      client: project.owner,
      contractor: offer.contractor,
      agreedPrice: offer.price,
      terms: offer.message || "",
      status: "active",
      startDate: new Date(),
    });

    try {
      await Notification.create({
        user: project.owner,
        userModel: "Client",
        title: "Contract created",
        body: `A contract was created for "${project.title}".`,
        type: "contract_created",
        projectId: project._id,
        read: false,
      });
    } catch (e) {
      console.error("notification contract_created failed:", e.message);
    }

    return res.json({
      message: "Offer accepted and contract created",
      project,
      contract,
    });
  } catch (err) {
    console.error("acceptOffer error:", err);
    return res.status(500).json({ error: err.message });
  }
};

// =======================
// Analyze Plan
// =======================
exports.analyzePlanOnly = async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ message: "Plan file is required" });

    const mime = req.file.mimetype || "";
    const name = (req.file.originalname || "").toLowerCase();
    const isImage = mime.startsWith("image/") || [".png", ".jpg", ".jpeg", ".webp"].some((e) => name.endsWith(e));

    if (!isImage) {
      return res.status(400).json({
        message: "Vision analysis requires an IMAGE (png/jpg/webp). Convert PDF to image first.",
        mimetype: mime,
      });
    }

    try {
      const analysis = await analyzeFloorPlanImage(req.file.path);
      return res.json({ message: "Plan analyzed successfully", analysis });
    } catch (e) {
      console.error("Vision analyze error:", e);
      const isRateLimit = e?.status === 429 || e?.code === "rate_limit_exceeded" || e?.error?.code === "rate_limit_exceeded";
      if (isRateLimit) {
        return res.status(503).json({
          message: "AI is unavailable now. Fill details manually.",
          code: "AI_UNAVAILABLE",
          retryAfterSeconds: 20,
        });
      }
      return res.status(502).json({
        message: "Vision analysis failed",
        code: "VISION_FAILED",
        error: e?.message || "Unknown error",
      });
    }
  } catch (err) {
    console.error("analyzePlanOnly error:", err);
    return res.status(500).json({ message: "Server error", error: err.message });
  }
};

// =======================
// Estimate
// =======================
exports.estimateProject = async (req, res) => {
  try {
    const projectId = req.params.id || req.params.projectId;
    const selections = Array.isArray(req.body.selections) ? req.body.selections : [];

    const project = await Project.findById(projectId);
    if (!project) return res.status(404).json({ message: "Project not found" });

    if (!req.user?._id) return res.status(401).json({ message: "Unauthorized" });
    if (String(project.owner) !== String(req.user._id)) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    const estimation = await generateBoqForProject(project, { selections });
    project.estimation = estimation;
    await project.save();

    return res.json({
      message: "Estimate generated",
      items: estimation.items,
      totalCost: estimation.totalCost,
      currency: estimation.currency,
      finishingLevel: estimation.finishingLevel,
      buildingType: estimation.buildingType,
    });
  } catch (err) {
    console.error("estimateProject error:", err);
    return res.status(500).json({ message: "Estimate failed", error: err.message });
  }
};

// =======================
// Save Project
// =======================
exports.saveProject = async (req, res) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) return res.status(404).json({ message: "Project not found" });
    if (String(project.owner) !== String(req.user._id)) {
      return res.status(403).json({ message: "Not owner of this project" });
    }
    project.isSaved = true;
    await project.save();
    return res.json({ message: "Project saved", project });
  } catch (err) {
    console.error("saveProject error:", err);
    return res.status(500).json({ message: "Save failed", error: err.message });
  }
};

// =======================
// Download
// =======================
exports.downloadEstimate = async (req, res) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) return res.status(404).json({ message: "Project not found" });
    if (String(project.owner) !== String(req.user._id)) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    const estimation = project.estimation || { items: [], totalCost: 0, currency: "JOD" };
    res.setHeader("Content-Disposition", `attachment; filename="estimate-${project._id}.json"`);
    return res.json(estimation);
  } catch (err) {
    console.error("downloadEstimate error:", err);
    return res.status(500).json({ message: "Download failed", error: err.message });
  }
};

// =======================
// Share
// =======================
exports.shareProject = async (req, res) => {
  try {
    const { contractorId } = req.body;
    if (!contractorId) return res.status(400).json({ message: "contractorId is required" });

    const project = await Project.findById(req.params.id);
    if (!project) return res.status(404).json({ message: "Project not found" });
    if (String(project.owner) !== String(req.user._id)) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    const contractor = await Contractor.findById(contractorId).select("name isActive role").lean();
    if (!contractor || contractor.role !== "contractor") return res.status(404).json({ message: "Contractor not found" });
    if (!contractor.isActive) return res.status(400).json({ message: "Contractor is not active" });

    project.sharedWithModel = "Contractor";
    project.sharedWith = project.sharedWith || [];
    const exists = project.sharedWith.some((id) => String(id) === String(contractorId));
    if (!exists) project.sharedWith.push(contractorId);

    await project.save();

    try {
      await Notification.create({
        user: contractorId,
        userModel: "Contractor",
        title: "Project shared",
        body: `A project was shared with you: "${project.title}".`,
        type: "project_shared",
        projectId: project._id,
        read: false,
      });
    } catch (e) {
      console.error("notification project_shared failed:", e.message);
    }

    return res.json({ message: "Project shared", project });
  } catch (err) {
    console.error("shareProject error:", err);
    return res.status(500).json({ message: "Share failed", error: err.message });
  }
};

// =======================
// Assign
// =======================
exports.assignContractor = async (req, res) => {
  try {
    const { contractorId } = req.body;
    if (!contractorId) return res.status(400).json({ message: "contractorId is required" });

    const project = await Project.findById(req.params.id);
    if (!project) return res.status(404).json({ message: "Project not found" });
    if (String(project.owner) !== String(req.user._id)) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    const contractor = await Contractor.findById(contractorId).select("name isActive role").lean();
    if (!contractor || contractor.role !== "contractor") return res.status(404).json({ message: "Contractor not found" });
    if (!contractor.isActive) return res.status(400).json({ message: "Contractor is not active" });

    project.contractor = contractorId;
    project.status = "in_progress";
    await project.save();

    try {
      await Notification.create({
        user: contractorId,
        userModel: "Contractor",
        title: "You were assigned",
        body: `You were assigned to project "${project.title}".`,
        type: "contractor_assigned",
        projectId: project._id,
        read: false,
      });
    } catch (e) {
      console.error("notification contractor_assigned failed:", e.message);
    }

    return res.json({ message: "Contractor assigned", project });
  } catch (err) {
    console.error("assignContractor error:", err);
    return res.status(500).json({ message: "Assign failed", error: err.message });
  }
};
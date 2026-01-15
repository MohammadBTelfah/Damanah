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

// ✅ make sure planAnalysis.rooms/bathrooms are NUMBERS (not list)
function sanitizePlanAnalysis(planAnalysis) {
  if (!planAnalysis || typeof planAnalysis !== "object") return undefined;

  const a = { ...planAnalysis };

  // totalArea
  if (a.totalArea !== undefined) {
    const d = toDouble(a.totalArea);
    if (d !== null) a.totalArea = d;
  }

  // floors
  if (a.floors !== undefined) {
    const n = toInt(a.floors);
    if (n !== null) a.floors = n;
  }

  // rooms
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

  // bathrooms
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

// =======================
// ✅ قائمة المقاولين المتاحين (للـ client)
// GET /api/contractors/available
// =======================
exports.getAvailableContractors = async (req, res) => {
  try {
    const contractors = await Contractor.find({
      emailVerified: true,
      contractorStatus: "verified",
      isActive: true,
    }).select("_id name email phone profileImage");

    return res.json(contractors);
  } catch (err) {
    console.error("getAvailableContractors error:", err);
    return res
      .status(500)
      .json({ message: "Failed to load contractors", error: err.message });
  }
};

// =======================
// إنشاء مشروع جديد (client)
// POST /api/projects
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

    // ✅ sanitize numbers
    const areaNum =
      area === null || area === undefined || area === "" ? null : Number(area);
    const floorsNum =
      floors === null || floors === undefined || floors === ""
        ? null
        : Number(floors);

    if (areaNum !== null && (!Number.isFinite(areaNum) || areaNum <= 0)) {
      return res.status(400).json({ message: "Invalid area" });
    }

    if (floorsNum !== null && (!Number.isFinite(floorsNum) || floorsNum <= 0)) {
      return res.status(400).json({ message: "Invalid floors" });
    }

    // ✅ normalize finishingLevel
    const level = String(finishingLevel || "basic").toLowerCase().trim();
    const allowedLevels = ["basic", "medium", "premium"];
    const safeLevel = allowedLevels.includes(level) ? level : "basic";

    // ✅ normalize buildingType (Flutter: house/villa/apartment/commercial)
    const bt = String(buildingType || "apartment").toLowerCase().trim();
    const allowedTypes = ["apartment", "villa", "commercial", "house"];
    let safeBuildingType = allowedTypes.includes(bt) ? bt : "apartment";

    // ✅ إذا DB/BOQ بدك تعتمد villa بدل house
    if (safeBuildingType === "house") safeBuildingType = "villa";

    // ✅ sanitize planAnalysis (مهم عشان مشكلة rooms array)
    const safePlanAnalysis =
      typeof sanitizePlanAnalysis === "function"
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
    });

    await project.save();

    // ✅ Notify client: project created
    try {
      await Notification.create({
        user: req.user._id,
        userModel: "Client",
        title: "Project created",
        body: `Your project "${project.title}" was created successfully.`,
        type: "project_created",
        projectId: project._id,
        read: false,
      });
    } catch (e) {
      console.error("notification project_created failed:", e.message);
    }

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
// Contractor - Available Projects
// GET /api/projects/contractor/available
// =======================
exports.getAvailableProjectsForContractor = async (req, res) => {
  try {
    const contractorId = req.user._id;

    const projects = await Project.find({
      status: "open",
      contractor: null,
      $or: [
        { sharedWith: contractorId },      // مشاريع مشاركة معه
        { sharedWith: { $exists: false } },// أو مشاريع بدون sharedWith
        { sharedWith: { $size: 0 } },      // أو sharedWith فاضي
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
// GET /api/projects/contractor/my
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
// GET /api/projects/my
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
// المشاريع المفتوحة (للمقاولين)
// GET /api/projects/open
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
// Contractor - Available Projects
// GET /api/projects/contractor/available
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
        { sharedWith: { $size: 0 } },
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
// GET /api/projects/contractor/my
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
// مشروع معيّن
// GET /api/projects/:projectId
// =======================
// =======================
// مشروع معيّن
// GET /api/projects/:projectId
// =======================
exports.getProjectById = async (req, res) => {
  try {
    const { projectId } = req.params;

    // ✅ يمنع CastError
    if (!mongoose.Types.ObjectId.isValid(projectId)) {
      return res.status(404).json({ message: "Project not found" });
    }

    const project = await Project.findById(projectId)
      .populate("owner", "name email")
      .populate("contractor", "name email")
      .populate("offers.contractor", "name email");

    if (!project) {
      return res.status(404).json({ message: "Project not found" });
    }

    return res.json(project);
  } catch (err) {
    console.error("getProjectById error:", err);
    return res.status(500).json({ error: err.message });
  }
};

// =======================
// المقاول يقدّم عرض على مشروع
// POST /api/projects/:projectId/offers
// =======================
exports.createOffer = async (req, res) => {
  try {
    const { price, message } = req.body;
    const { projectId } = req.params;

    if (!price) {
      return res.status(400).json({ message: "Price is required" });
    }

    const project = await Project.findById(projectId);
    if (!project) return res.status(404).json({ message: "Project not found" });

    if (project.status !== "open") {
      return res
        .status(400)
        .json({ message: "Offers are only allowed on open projects" });
    }

    const exists = project.offers.find(
      (o) => o.contractor.toString() === req.user._id.toString()
    );
    if (exists) {
      return res
        .status(400)
        .json({ message: "You already submitted an offer for this project" });
    }

    project.offers.push({
      contractor: req.user._id,
      price,
      message,
    });

    await project.save();

    // ✅ Notify client (project owner): new offer
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
// العميل يشوف العروض على مشروعه
// GET /api/projects/:projectId/offers
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
// العميل يقبل عرض + إنشاء عقد
// POST /api/projects/:projectId/offers/:offerId/accept
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
      o.status =
        o._id.toString() === offerId.toString() ? "accepted" : "rejected";
    });

    await project.save();

    // ✅ Notify contractor: offer accepted
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

    // ✅ Notify client: contract created (اختياري لكنه مفيد)
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
// Analyze plan only
// POST /api/projects/plan/analyze
// =======================
exports.analyzePlanOnly = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: "Plan file is required" });
    }

    const mime = req.file.mimetype || "";
    const name = (req.file.originalname || "").toLowerCase();
    const isImage =
      mime.startsWith("image/") ||
      [".png", ".jpg", ".jpeg", ".webp"].some((e) => name.endsWith(e));

    if (!isImage) {
      return res.status(400).json({
        message:
          "Vision analysis requires an IMAGE (png/jpg/webp). Convert PDF to image first.",
        mimetype: mime,
      });
    }

    try {
      const analysis = await analyzeFloorPlanImage(req.file.path);
      return res.json({ message: "Plan analyzed successfully", analysis });
    } catch (e) {
      console.error("Vision analyze error:", e);

      const isRateLimit =
        e?.status === 429 ||
        e?.code === "rate_limit_exceeded" ||
        e?.error?.code === "rate_limit_exceeded";

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
// Estimate + save into project
// POST /api/projects/:id/estimate
// =======================
exports.estimateProject = async (req, res) => {
  try {
    const projectId = req.params.id || req.params.projectId;
    const selections = Array.isArray(req.body.selections)
      ? req.body.selections
      : [];

    const project = await Project.findById(projectId);
    if (!project) return res.status(404).json({ message: "Project not found" });

    if (!req.user?._id)
      return res.status(401).json({ message: "Unauthorized" });

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
    return res
      .status(500)
      .json({ message: "Estimate failed", error: err.message });
  }
};

// =======================
// Save project (isSaved = true)
// POST /api/projects/:id/save
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
// Download estimate JSON
// GET /api/projects/:id/estimate/download
// =======================
exports.downloadEstimate = async (req, res) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) return res.status(404).json({ message: "Project not found" });

    if (String(project.owner) !== String(req.user._id)) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    const estimation =
      project.estimation || { items: [], totalCost: 0, currency: "JOD" };

    res.setHeader(
      "Content-Disposition",
      `attachment; filename="estimate-${project._id}.json"`
    );
    return res.json(estimation);
  } catch (err) {
    console.error("downloadEstimate error:", err);
    return res
      .status(500)
      .json({ message: "Download failed", error: err.message });
  }
};

// =======================
// Share project with contractor
// POST /api/projects/:id/share  body:{ contractorId }
// =======================
exports.shareProject = async (req, res) => {
  try {
    const { contractorId } = req.body;
    if (!contractorId) {
      return res.status(400).json({ message: "contractorId is required" });
    }

    const project = await Project.findById(req.params.id);
    if (!project) return res.status(404).json({ message: "Project not found" });

    if (String(project.owner) !== String(req.user._id)) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    // ✅ validate contractor exists + active
    const contractor = await Contractor.findById(contractorId)
      .select("name isActive role")
      .lean();

    if (!contractor || contractor.role !== "contractor") {
      return res.status(404).json({ message: "Contractor not found" });
    }
    if (!contractor.isActive) {
      return res.status(400).json({ message: "Contractor is not active" });
    }

    project.sharedWithModel = "Contractor";
    project.sharedWith = project.sharedWith || [];

    const exists = project.sharedWith.some(
      (id) => String(id) === String(contractorId)
    );
    if (!exists) project.sharedWith.push(contractorId);

    await project.save();

    // ✅ Notify contractor: project shared
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
// Assign contractor
// POST /api/projects/:id/assign  body:{ contractorId }
// =======================
exports.assignContractor = async (req, res) => {
  try {
    const { contractorId } = req.body;
    if (!contractorId) {
      return res.status(400).json({ message: "contractorId is required" });
    }

    const project = await Project.findById(req.params.id);
    if (!project) return res.status(404).json({ message: "Project not found" });

    if (String(project.owner) !== String(req.user._id)) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    // ✅ validate contractor exists + active
    const contractor = await Contractor.findById(contractorId)
      .select("name isActive role")
      .lean();

    if (!contractor || contractor.role !== "contractor") {
      return res.status(404).json({ message: "Contractor not found" });
    }
    if (!contractor.isActive) {
      return res.status(400).json({ message: "Contractor is not active" });
    }

    project.contractor = contractorId;
    project.status = "in_progress";

    await project.save();

    // ✅ Notify contractor: assigned
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

// =======================
// Upload plan + analyze + estimate
// POST /api/projects/:projectId/plan/upload
// =======================
exports.uploadPlanAndEstimate = async (req, res) => {
  try {
    const { projectId } = req.params;
    const selections = Array.isArray(req.body?.selections)
      ? req.body.selections
      : [];

    const project = await Project.findById(projectId);
    if (!project) return res.status(404).json({ message: "Project not found" });

    if (!req.user?._id) return res.status(401).json({ message: "Unauthorized" });

    if (String(project.owner) !== String(req.user._id)) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    if (!req.file) {
      return res.status(400).json({ message: "Plan file is required" });
    }

    project.planFile = req.file.path;

    const mime = req.file.mimetype || "";
    const name = (req.file.originalname || "").toLowerCase();
    const isImage =
      mime.startsWith("image/") ||
      [".png", ".jpg", ".jpeg", ".webp"].some((e) => name.endsWith(e));

    if (!isImage) {
      return res.status(400).json({
        message:
          "Currently Vision analysis expects an IMAGE (png/jpg/webp). Convert PDF to image first.",
        mimetype: mime,
      });
    }

    let analysis = null;
    try {
      analysis = await analyzeFloorPlanImage(req.file.path);

      project.planAnalysis = sanitizePlanAnalysis(analysis);

      if (analysis?.totalArea && Number(analysis.totalArea) > 0) {
        project.area = Number(analysis.totalArea);
      }
      if (analysis?.floors && Number(analysis.floors) > 0) {
        project.floors = Number(analysis.floors);
      }
    } catch (e) {
      console.error("Vision analyze error:", e);

      const isRateLimit =
        e?.status === 429 ||
        e?.code === "rate_limit_exceeded" ||
        e?.error?.code === "rate_limit_exceeded";

      if (isRateLimit) {
        await project.save();
        return res.status(503).json({
          message: "AI is unavailable now. Continue manually (area/floors).",
          code: "AI_UNAVAILABLE",
          planFileUrl: project.planFile,
          projectId: project._id,
        });
      }

      return res.status(502).json({
        message: "Vision analysis failed",
        code: "VISION_FAILED",
        error: e?.message || "Unknown error",
      });
    }

    const estimation = await generateBoqForProject(project, { selections });
    project.estimation = estimation;

    await project.save();

    return res.json({
      message: "Plan uploaded, estimate generated.",
      planAnalysis: project.planAnalysis,
      estimation: project.estimation,
      planFileUrl: project.planFile,
    });
  } catch (err) {
    console.error("uploadPlanAndEstimate error:", err);
    return res.status(500).json({ error: err.message });
  }
};

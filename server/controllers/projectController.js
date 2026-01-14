const Project = require("../models/Project");
const Contract = require("../models/Contract");
const { generateBoqForProject } = require("../utils/boq"); // ✅ FIX
const { analyzeFloorPlanImage } = require("../utils/plan_vision");



// retry wrapper


// =======================
// إنشاء مشروع جديد (client)
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
      buildingType,   // ✅ جديد
      planAnalysis,   // ✅ جديد (اختياري)
    } = req.body;

    if (!title || String(title).trim().length === 0) {
      return res.status(400).json({ message: "Title is required" });
    }

    // ✅ sanitize numbers
    const areaNum =
      area === null || area === undefined || area === ""
        ? null
        : Number(area);

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

    // ✅ normalize buildingType
    const bt = String(buildingType || "apartment").toLowerCase().trim();
    const allowedTypes = ["apartment", "villa", "commercial"];
    const safeBuildingType = allowedTypes.includes(bt) ? bt : "apartment";

    const project = new Project({
      owner: req.user._id,
      title: String(title).trim(),
      description: description ? String(description).trim() : "",
      location: location ? String(location).trim() : "",
      area: areaNum,
      floors: floorsNum,
      finishingLevel: safeLevel,
      buildingType: safeBuildingType, // ✅ جديد
      planAnalysis: planAnalysis && typeof planAnalysis === "object" ? planAnalysis : undefined, // ✅ اختياري
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
// المشاريع المفتوحة (للمقاولين)
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
    const project = await Project.findById(req.params.projectId)
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
    return res.status(201).json({ message: "Offer submitted", project });
  } catch (err) {
    console.error("createOffer error:", err);
    return res.status(500).json({ error: err.message });
  }
};

// =======================
// العميل يشوف العروض على مشروعه
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
// العميل يقبل عرض معيّن + إنشاء عقد
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

    const contract = await Contract.create({
      project: project._id,
      client: project.owner,
      contractor: offer.contractor,
      agreedPrice: offer.price,
      terms: offer.message || "",
      status: "active",
      startDate: new Date(),
    });

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
        message: "Vision analysis requires an IMAGE (png/jpg/webp). Convert PDF to image first.",
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
// Estimate (BOQ real) + save into project

// =======================


exports.estimateProject = async (req, res) => {
  try {
    const projectId = req.params.id || req.params.projectId;

    // selections ممكن تكون []
    const selections = Array.isArray(req.body.selections) ? req.body.selections : [];

    console.log("ESTIMATE projectId:", projectId);
    console.log("ESTIMATE selections:", selections);

    const project = await Project.findById(projectId);
    if (!project) return res.status(404).json({ message: "Project not found" });

    // ✅ لازم تتأكد من protect موجود في الراوت (عشان req.user)
    if (!req.user?._id) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    // ✅ owner check
    if (String(project.owner) !== String(req.user._id)) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    // ✅ BOQ الحقيقي (حتى لو selections = [])
    const estimation = await generateBoqForProject(project, { selections });

    // ✅ خزّن النتيجة
    project.estimation = estimation;
    await project.save();

    return res.json({
      message: "Estimate generated",
      items: estimation.items,
      totalCost: estimation.totalCost,
      currency: estimation.currency,
      finishingLevel: estimation.finishingLevel,
    });
  } catch (err) {
    console.error("estimateProject error:", err);
    return res.status(500).json({ message: "Estimate failed", error: err.message });
  }
};

//======================= ======
// حفظ المشروع (isSaved = true)
// =======================
// ✅ حفظ المشروع
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

// ✅ تنزيل التقدير JSON
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

// ✅ مشاركة مشروع مع مقاول
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

    // ✅ sharedWithModel حاليا Contractor
    project.sharedWithModel = "Contractor";
    project.sharedWith = project.sharedWith || [];

    const exists = project.sharedWith.some(
      (id) => String(id) === String(contractorId)
    );
    if (!exists) project.sharedWith.push(contractorId);

    await project.save();

    return res.json({ message: "Project shared", project });
  } catch (err) {
    console.error("shareProject error:", err);
    return res.status(500).json({ message: "Share failed", error: err.message });
  }
};

// ✅ تعيين مقاول (اختيار مقاول معيّن)
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

    project.contractor = contractorId;
    await project.save();

    return res.json({ message: "Contractor assigned", project });
  } catch (err) {
    console.error("assignContractor error:", err);
    return res
      .status(500)
      .json({ message: "Assign failed", error: err.message });
  }
};




// =======================
// رفع مخطط + Vision AI + BOQ
// =======================

exports.uploadPlanAndEstimate = async (req, res) => {
  try {
    const { projectId } = req.params;

    // selections اختياري (عشان لو بدك تستخدم نفس endpoint)
    const selections = Array.isArray(req.body?.selections) ? req.body.selections : [];

    const project = await Project.findById(projectId);
    if (!project) return res.status(404).json({ message: "Project not found" });

    if (!req.user?._id) {
      return res.status(401).json({ message: "Unauthorized" });
    }

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
        message: "Currently Vision analysis expects an IMAGE (png/jpg/webp). Convert PDF to image first.",
        mimetype: mime,
      });
    }

    // ✅ حاول تعمل تحليل، وإذا AI مش متاح خليه manual
    let analysis = null;
    try {
      analysis = await analyzeFloorPlanImage(req.file.path);
      project.planAnalysis = analysis;

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
        // ✅ لا تضيّع وقت المستخدم — رجّعله manual mode
        await project.save();
        return res.status(503).json({
          message: "AI is unavailable now. Continue manually (area/floors).",
          code: "AI_UNAVAILABLE",
          planFileUrl: project.planFile,
          projectId: project._id,
        });
      }

      // أي خطأ ثاني
      return res.status(502).json({
        message: "Vision analysis failed",
        code: "VISION_FAILED",
        error: e?.message || "Unknown error",
      });
    }

    // ✅ BOQ (always) — لازم await
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

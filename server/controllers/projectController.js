const Project = require("../models/Project");
const Contract = require("../models/Contract");
const { generateBoqForProject } = require("../utils/boq."); // ✅ FIX
const { analyzeFloorPlanImage } = require("../utils/plan_vision");


const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// retry wrapper
async function analyzeWithRetry(imagePath, maxRetries = 2) {
  let attempt = 0;

  while (true) {
    try {
      return await analyzeFloorPlanImage(imagePath);
    } catch (e) {
      const isRateLimit =
        e?.status === 429 ||
        e?.code === "rate_limit_exceeded" ||
        e?.error?.code === "rate_limit_exceeded";

      if (!isRateLimit || attempt >= maxRetries) {
        throw e;
      }

      // retry-after (إن وجد)
      const retryAfterHeader =
        e?.headers?.get?.("retry-after") || e?.headers?.["retry-after"];

      const retryAfterSeconds =
        retryAfterHeader && Number(retryAfterHeader)
          ? Number(retryAfterHeader)
          : 20;

      console.warn(
        `Rate limit hit. Retry ${attempt + 1}/${maxRetries} after ${retryAfterSeconds}s`
      );

      await sleep((retryAfterSeconds + 1) * 1000);
      attempt++;
    }
  }
}



// =======================
// إنشاء مشروع جديد (client)
// =======================
exports.createProject = async (req, res) => {
  try {
    const { title, description, location, area, floors, finishingLevel } =
      req.body;

    if (!title || String(title).trim().isEmpty) {
      return res.status(400).json({ message: "Title is required" });
    }

    const project = new Project({
      owner: req.user._id,
      title: String(title).trim(),
      description: description ? String(description).trim() : "",
      location: location ? String(location).trim() : "",
      area: area ?? null,
      floors: floors ?? null,
      finishingLevel: finishingLevel ?? "basic",
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
        message:
          "Vision analysis requires an IMAGE (png/jpg/webp). Convert PDF to image first.",
        mimetype: mime,
      });
    }

    let analysis;
    try {
      // ✅ analyze مع retry تلقائي
      analysis = await analyzeWithRetry(req.file.path, 2);
    } catch (e) {
      console.error("Vision analyze error:", e);

      const isRateLimit =
        e?.status === 429 ||
        e?.code === "rate_limit_exceeded" ||
        e?.error?.code === "rate_limit_exceeded";

      if (isRateLimit) {
        return res.status(429).json({
          message: "AI is busy right now. Please try again shortly.",
          code: "RATE_LIMIT",
          retryAfterSeconds: 20,
        });
      }

      return res.status(502).json({
        message: "Vision analysis failed",
        error: e?.message || "Unknown error",
      });
    }

    return res.json({
      message: "Plan analyzed successfully",
      analysis,
    });
  } catch (err) {
    console.error("analyzePlanOnly error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
};





// =======================
// رفع مخطط + Vision AI + BOQ
// =======================

exports.uploadPlanAndEstimate = async (req, res) => {
  try {
    const { projectId } = req.params;

    const project = await Project.findById(projectId);
    if (!project) return res.status(404).json({ message: "Project not found" });

    if (project.owner.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    if (!req.file) {
      return res.status(400).json({ message: "Plan file is required" });
    }

    // ✅ احفظ المسار
    project.planFile = req.file.path;

    // ✅ إذا الملف PDF وانت ما بتحوله لصورة: رجّع رسالة واضحة
    const mime = req.file.mimetype || "";
    const isImage =
      mime.startsWith("image/") ||
      [".png", ".jpg", ".jpeg", ".webp"].some((e) =>
        String(req.file.originalname || "").toLowerCase().endsWith(e)
      );

    if (!isImage) {
      return res.status(400).json({
        message:
          "Currently Vision analysis expects an IMAGE (png/jpg/webp). Convert PDF to image first.",
        mimetype: mime,
      });
    }

    // (اختياري) إذا بدك تمنع إعادة التحليل لو موجود:
    // if (project.planAnalysis) {
    //   return res.json({
    //     message: "Plan already analyzed",
    //     planAnalysis: project.planAnalysis,
    //     estimation: project.estimation,
    //     planFileUrl: project.planFile,
    //   });
    // }

    // ✅ Vision AI الحقيقي
    let analysis;
    try {
      analysis = await analyzeFloorPlanImage(req.file.path);
    } catch (e) {
      console.error("Vision analyze error:", e);
      return res.status(502).json({
        message: "Vision analysis failed",
        error: e.message,
      });
    }

    project.planAnalysis = analysis;

    // ✅ تحديث area/floors بعقلانية
    if (analysis && typeof analysis.totalArea === "number" && analysis.totalArea > 0) {
      project.area = analysis.totalArea;
    }
    if (analysis && typeof analysis.floors === "number" && analysis.floors > 0) {
      project.floors = analysis.floors;
    }

    // ✅ BOQ
    const estimation = generateBoqForProject(project);
    project.estimation = estimation;

    await project.save();

    return res.json({
      message: "Plan uploaded and analyzed with Vision AI, BOQ generated.",
      planAnalysis: project.planAnalysis,
      estimation: project.estimation,
      planFileUrl: project.planFile,
    });
  } catch (err) {
    console.error("uploadPlanAndEstimate error:", err);
    return res.status(500).json({ error: err.message });
  }
};

const Project = require("../models/Project");
const Contract = require("../models/Contract");
const { generateBoqForProject } = require("../utils/boq.");

// =======================
// إنشاء مشروع جديد (client)
// =======================
exports.createProject = async (req, res) => {
  try {
    const { title, description, location, area, floors, finishingLevel } =
      req.body;

    if (!title) {
      return res.status(400).json({ message: "Title is required" });
    }

    const project = new Project({
      owner: req.user._id,
      title,
      description,
      location,
      area,
      floors,
      finishingLevel,
    });

    await project.save();

    res.status(201).json({
      message: "Project created successfully",
      project,
    });
  } catch (err) {
    console.error("createProject error:", err);
    res.status(500).json({ error: err.message });
  }
};

// =======================
// مشاريعي (client)
// =======================
exports.getMyProjects = async (req, res) => {
  try {
    const projects = await Project.find({ owner: req.user._id })
      .populate("owner", "name email")
      .populate("contractor", "name email");

    res.json(projects);
  } catch (err) {
    console.error("getMyProjects error:", err);
    res.status(500).json({ error: err.message });
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
      .populate("contractor", "name email");

    res.json(projects);
  } catch (err) {
    console.error("getOpenProjects error:", err);
    res.status(500).json({ error: err.message });
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

    res.json(project);
  } catch (err) {
    console.error("getProjectById error:", err);
    res.status(500).json({ error: err.message });
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
    if (!project) {
      return res.status(404).json({ message: "Project not found" });
    }

    if (project.status !== "open") {
      return res
        .status(400)
        .json({ message: "Offers are only allowed on open projects" });
    }

    // ممنوع نفس المقاول يقدم عرضين على نفس المشروع
    const existing = project.offers.find(
      (o) => o.contractor.toString() === req.user._id.toString()
    );
    if (existing) {
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

    res.status(201).json({ message: "Offer submitted", project });
  } catch (err) {
    console.error("createOffer error:", err);
    res.status(500).json({ error: err.message });
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

    if (!project) {
      return res.status(404).json({ message: "Project not found" });
    }

    if (project.owner._id.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    res.json(project.offers);
  } catch (err) {
    console.error("getProjectOffers error:", err);
    res.status(500).json({ error: err.message });
  }
};

// =======================
// العميل يقبل عرض معيّن + إنشاء عقد
// =======================
exports.acceptOffer = async (req, res) => {
  try {
    const { projectId, offerId } = req.params;

    const project = await Project.findById(projectId);
    if (!project) {
      return res.status(404).json({ message: "Project not found" });
    }

    if (project.owner.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    const offer = project.offers.id(offerId);
    if (!offer) {
      return res.status(404).json({ message: "Offer not found" });
    }

    project.contractor = offer.contractor;
    project.status = "in_progress";

    project.offers.forEach((o) => {
      if (o._id.toString() === offerId.toString()) {
        o.status = "accepted";
      } else {
        o.status = "rejected";
      }
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

    res.json({
      message: "Offer accepted and contract created",
      project,
      contract,
    });
  } catch (err) {
    console.error("acceptOffer error:", err);
    res.status(500).json({ error: err.message });
  }
};

// =======================
// رفع مخطط + Mock AI + BOQ
// =======================
exports.uploadPlanAndEstimate = async (req, res) => {
  try {
    const { projectId } = req.params;

    const project = await Project.findById(projectId);
    if (!project) {
      return res.status(404).json({ message: "Project not found" });
    }

    if (project.owner.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    if (!req.file) {
      return res.status(400).json({ message: "Plan file is required" });
    }

    project.planFile = req.file.path;

    // Mock AI: لاحقاً بتستبدله باستدعاء حقيقي لـ Vision
    const mockAiResult = {
      totalArea: project.area || 180,
      floors: project.floors || 1,
      rooms: 6,
      bathrooms: 3,
    };

    project.planAnalysis = mockAiResult;
    project.area = mockAiResult.totalArea;
    project.floors = mockAiResult.floors;

    const estimation = generateBoqForProject(project);
    project.estimation = estimation;

    await project.save();

    res.json({
      message:
        "Plan uploaded, mock AI analysis applied and BOQ estimation calculated.",
      planAnalysis: project.planAnalysis,
      estimation: project.estimation,
      planFileUrl: `/uploads/${req.file.filename}`,
    });
  } catch (err) {
    console.error("uploadPlanAndEstimate error:", err);
    res.status(500).json({ error: err.message });
  }
};

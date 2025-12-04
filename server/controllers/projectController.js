const Project = require("../models/Project");

// إنشاء مشروع جديد (client)
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
    res.status(500).json({ error: err.message });
  }
};

// مشاريعي (العميل)
exports.getMyProjects = async (req, res) => {
  try {
    const projects = await Project.find({ owner: req.user._id })
      .populate("owner", "name email")
      .populate("contractor", "name email");

    res.json(projects);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// المشاريع المفتوحة (للمقاولين)
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
    res.status(500).json({ error: err.message });
  }
};

// مشروع معيّن
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
    res.status(500).json({ error: err.message });
  }
};

//
// ========================= OFFERS =========================
//

// المقاول يقدّم عرض على مشروع معيّن
// POST /api/projects/:projectId/offers
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

    // لازم المشروع يكون مفتوح
    if (project.status !== "open") {
      return res
        .status(400)
        .json({ message: "Offers are only allowed on open projects" });
    }

    // ممنوع نفس المقاول يقدم أكثر من عرض على نفس المشروع
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
    res.status(500).json({ error: err.message });
  }
};

// العميل يشوف كل العروض على مشروعه
// GET /api/projects/:projectId/offers
exports.getProjectOffers = async (req, res) => {
  try {
    const { projectId } = req.params;

    const project = await Project.findById(projectId)
      .populate("offers.contractor", "name email phone")
      .populate("owner", "name email");

    if (!project) {
      return res.status(404).json({ message: "Project not found" });
    }

    // تأكد إنه صاحب المشروع
    if (project.owner._id.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    res.json(project.offers);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// العميل يقبل عرض معيّن
// PATCH /api/projects/:projectId/offers/:offerId/accept
exports.acceptOffer = async (req, res) => {
  try {
    const { projectId, offerId } = req.params;

    const project = await Project.findById(projectId);
    if (!project) {
      return res.status(404).json({ message: "Project not found" });
    }

    // تأكد إنه صاحب المشروع
    if (project.owner.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    const offer = project.offers.id(offerId);
    if (!offer) {
      return res.status(404).json({ message: "Offer not found" });
    }

    // تعيين المقاول للمشروع
    project.contractor = offer.contractor;
    project.status = "in_progress";

    // تحديث حالة العروض
    project.offers.forEach((o) => {
      if (o._id.toString() === offerId.toString()) {
        o.status = "accepted";
      } else {
        o.status = "rejected";
      }
    });

    await project.save();

    res.json({ message: "Offer accepted", project });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

const Project = require("../models/Project");
const Contract = require("../models/Contract");
const Contractor = require("../models/Contractor");
const Notification = require("../models/Notification");
const generateContractPdf = require("../utils/pdf/generateContractPdf");

const { generateBoqForProject } = require("../utils/boq");
const { analyzeFloorPlanImage } = require("../utils/plan_vision");
// ✅ التصحيح: استدعاء ملف الكونفيج مباشرة
const cloudinary = require("../config/cloudinaryConfig");
const mongoose = require("mongoose");
const fs = require("fs");
const path = require("path");
const os = require("os");
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
// ✅ Available contractors (client)
// =======================
exports.getAvailableContractors = async (req, res) => {
  try {
    const contractors = await Contractor.find({
      emailVerified: true,
      contractorStatus: "verified",
      isActive: true,
    }).select("_id name email phone profileImage");

    const baseUrl = getBaseUrl(req);  // تأكد من أن baseUrl يحتوي على البروتوكول (http:// أو https://)
    const list = contractors.map((c) => {
      const obj = c.toObject();
      return {
        ...obj,
        profileImageUrl: obj.profileImage
          ? obj.profileImage.startsWith("http")  // إذا كان الرابط يحتوي على بروتوكول (مثل http:// أو https://)
            ? obj.profileImage  // إذا كان الرابط يحتوي على بروتوكول، نتركه كما هو
            : `${baseUrl}${obj.profileImage}`  // إذا كان الرابط محليًا، ندمج baseUrl مع المسار
          : null,  // إذا كانت الصورة غير موجودة، نضع القيمة null
      };
    });

    return res.json(list);  // إرجاع القائمة للمستعرض
  } catch (err) {
    console.error("getAvailableContractors error:", err);
    return res
      .status(500)
      .json({ message: "Failed to load contractors", error: err.message });
  }
};

// =======================
// Create project
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

    // معالجة مستوى التشطيب
    const level = String(finishingLevel || "basic").toLowerCase().trim();
    const allowedLevels = ["basic", "medium", "premium"];
    const safeLevel = allowedLevels.includes(level) ? level : "basic";

    // ✅ معالجة نوع البناء (بدون تحويل House إلى Villa)
    const bt = String(buildingType || "House").toLowerCase().trim();
    let safeBuildingType = "House"; // القيمة الافتراضية (House)

    if (bt === "villa") {
      safeBuildingType = "villa";
    } else if (bt === "commercial") {
      safeBuildingType = "commercial";
    } else {
      // أي شيء آخر (بما فيه house) سيصبح House
      safeBuildingType = "House";
    }

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
      buildingType: safeBuildingType, // ✅ سيحفظ القيمة الصحيحة الآن
      planAnalysis: safePlanAnalysis,
      status: "draft",
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
// Publish project
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

    project.status = "open";
    project.sharedWith = [];
    project.sharedWithModel = undefined;
    project.isSaved = true;

    await project.save();

    return res.json({ message: "Project published to all contractors", project });
  } catch (err) {
    console.error("publishProject error:", err);
    return res
      .status(500)
      .json({ message: "Publish failed", error: err.message });
  }
};

// =======================
// Contractor - Available projects
// =======================
// projectController.js

exports.getAvailableProjectsForContractor = async (req, res) => {
  try {
    const contractorId = req.user._id;
    const baseUrl = getBaseUrl(req); // نستخدم الهيلبر الموجود عندك

    const projects = await Project.find({
      $or: [
        { status: "open", contractor: null }, 
        { contractor: contractorId, status: { $in: ["open", "in_progress"] } }
      ]
    })
    .sort({ createdAt: -1 })
    .populate("owner", "name profileImage city"); 

    // ✅ تعديل الروابط لتصبح كاملة قبل الإرسال
    const processedProjects = projects.map(project => {
      const p = project.toObject();
      if (p.owner && p.owner.profileImage) {
        p.owner.profileImage = p.owner.profileImage.startsWith('http') 
          ? p.owner.profileImage 
          : `${baseUrl}${p.owner.profileImage.replaceAll('\\', '/')}`;
      }
      return p;
    });

    return res.json(processedProjects);
  } catch (err) {
    console.error("Error in getAvailableProjectsForContractor:", err);
    return res.status(500).json({ message: "Server error" });
  }
};// =======================
// Contractor - My projects
// =======================
exports.getMyProjectsForContractor = async (req, res) => {
  try {
    const contractorId = req.user._id;
    const projects = await Project.find({
      contractor: contractorId,
    })
      // ✅ التعديل هنا: أضفنا profileImage و phone
      .populate("owner", "name email profileImage phone")
      .sort({ createdAt: -1 });

    return res.json({ projects });
  } catch (err) {
    console.error("getMyProjectsForContractor error:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

// =======================
// My projects (client)
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
// Open projects
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
// Get project by ID
// =======================
// =======================
// Get project by ID
// =======================
exports.getProjectById = async (req, res) => {
  try {
    const { projectId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(projectId)) {
      return res.status(404).json({ message: "Project not found" });
    }
    const project = await Project.findById(projectId)
      // ✅ التعديل: أضفنا profileImage و phone
      .populate("owner", "name email profileImage phone") 
      .populate(
        "contractor",
        "_id name email phone profileImage contractorStatus isActive"
      )
      .populate("offers.contractor", "_id name email phone profileImage");

    if (!project) return res.status(404).json({ message: "Project not found" });
    return res.json(project);
  } catch (err) {
    console.error("getProjectById error:", err);
    return res.status(500).json({ error: err.message });
  }
};

// =======================
// ✅ Create/Update Offer (Contractor)  (UPSERT)
// =======================
// =======================
// ✅ Create Offer OR (if exists) Create Contract (Contractor)
// =======================
exports.createOffer = async (req, res) => {
  try {
    const { projectId } = req.params;

    const priceNum = Number(req.body.price);
    const message = (req.body.message || "").toString().trim();

    if (!Number.isFinite(priceNum) || priceNum <= 0) {
      return res.status(400).json({ message: "Price is required" });
    }

    const project = await Project.findById(projectId);
    if (!project) return res.status(404).json({ message: "Project not found" });

    if (project.status !== "open") {
      return res
        .status(400)
        .json({ message: "Offers are only allowed on open projects" });
    }

    const contractorId = req.user._id.toString();

    // If offer exists -> بدل update: create contract
    const existing = project.offers.find(
      (o) => o.contractor.toString() === contractorId
    );

    if (existing) {
      // ✅ امنع تكرار العقد لنفس المشروع
      const already = await Contract.findOne({ project: project._id });
      if (already) {
        return res.status(200).json({
          message: "Contract already exists for this project",
          project,
          contract: already,
        });
      }

      // (اختياري) لو بدك تثبيت السعر المتفق عليه في نفس الـ Offer:
      existing.price = priceNum;
      existing.message = message;

      // اربط المقاول بالمشروع وغيّر الحالة
      project.contractor = req.user._id;
      project.status = "in_progress";
      project.agreedPrice = priceNum;

      // snapshot اختياري مثل acceptOffer عندك
      project.acceptedOffer = {
        contractor: req.user._id,
        price: priceNum,
        message: message || "",
        offerId: existing._id,
        acceptedAt: new Date(),
      };

      // علّم عرض هذا المقاول accepted والباقي rejected (اختياري)
      project.offers.forEach((o) => {
        o.status =
          o.contractor.toString() === contractorId ? "accepted" : "rejected";
      });

      await project.save();

      // ✅ Create Contract (واحد للطرفين)
      const contract = await Contract.create({
        project: project._id,
        client: project.owner,
        contractor: req.user._id,
        agreedPrice: priceNum,
        terms: message || "",
        status: "active",
        startDate: new Date(),
      });

      // Notifications للطرفين
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

        await Notification.create({
          user: req.user._id,
          userModel: "Contractor",
          title: "Contract created",
          body: `A contract was created for "${project.title}".`,
          type: "contract_created",
          projectId: project._id,
          read: false,
        });
      } catch (e) {
        console.error("notification contract_created failed:", e.message);
      }

      return res.status(201).json({
        message: "Contract created (instead of updating offer)",
        project,
        contract,
      });
    }

    // Otherwise -> create new offer (مثل ما هو عندك)
    project.offers.push({
      contractor: req.user._id,
      price: priceNum,
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
// Update Project Status
// =======================
// projectController.js
exports.updateProjectStatus = async (req, res) => {
  try {
    const { id } = req.params; // تأكد أن الاسم يطابق الراوتر (:id)
    const { status } = req.body;

    const project = await Project.findById(id);
    if (!project) {
      return res.status(404).json({ message: "المشروع غير موجود" });
    }

    // السماح للمقاول المسجل في المشروع فقط بالتحديث
    // تأكد أن حقل المقاول في موديل المشروع اسمه contractor
    if (String(project.contractor) !== String(req.user._id)) {
      return res.status(403).json({ message: "فقط المقاول المسؤول عن المشروع يمكنه تغيير الحالة" });
    }

    project.status = status;
    await project.save();

    return res.status(200).json({
      message: "تم تحديث الحالة بنجاح",
      project,
    });
  } catch (err) {
    return res.status(500).json({ message: "خطأ في السيرفر", error: err.message });
  }
};
// Get offers
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
// Accept offer
// =======================
// =======================
// Accept offer
// =======================
// تأكد من أن مسار الكلاوديناري صحيح حسب ملفات مشروعك

// =======================
// Accept offer (Modified & Fixed)
// =======================
exports.acceptOffer = async (req, res) => {
  try {
    const { projectId, offerId } = req.params;

    // 1) جلب المشروع
    const project = await Project.findById(projectId);
    if (!project) return res.status(404).json({ message: "Project not found" });

    // 2) تحقق إن المستخدم هو صاحب المشروع (العميل)
    if (String(project.owner) !== String(req.user._id)) {
      return res.status(403).json({ message: "Not authorized" });
    }

    // 3) جلب العرض
    const offer = project.offers.id(offerId);
    if (!offer) return res.status(404).json({ message: "Offer not found" });

    // 4) تحديث بيانات المشروع
    project.contractor = offer.contractor;
    project.status = "in_progress";
    project.agreedPrice = offer.price;

    // snapshot (اختياري)
    project.acceptedOffer = {
      contractor: offer.contractor,
      price: offer.price,
      message: offer.message || "",
      offerId: offer._id,
      acceptedAt: new Date(),
    };

    // علّم العروض (المقبول والمرفوض)
    project.offers.forEach((o) => {
      o.status = String(o._id) === String(offerId) ? "accepted" : "rejected";
    });

    await project.save();

    // 5) إشعار للمقاول (اختياري)
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

    // 6) منع تكرار العقد لنفس المشروع
    let contract = await Contract.findOne({ project: project._id });

    // 7) إنشاء العقد إذا غير موجود
    if (!contract) {
      contract = await Contract.create({
        project: project._id,
        client: project.owner,
        contractor: offer.contractor,
        agreedPrice: offer.price,
        terms: offer.message || "",
        status: "active",
        startDate: new Date(),
      });
    }

    // =========================================================
    // 8) توليد PDF ورفعه (محمية بـ Try/Catch منفصل)
    // =========================================================
    try {
      if (!contract.contractFile) {
        // Populating required fields for PDF generation
        const populated = await Contract.findById(contract._id)
          .populate("project")
          .populate("client")
          .populate("contractor");

        const tempDir = os.tmpdir();
        const tempFilePath = path.join(tempDir, `contract-${contract._id}.pdf`);

        // توليد PDF
        await generateContractPdf(populated, tempFilePath);

        // رفع Cloudinary
        const uploadResult = await cloudinary.uploader.upload(tempFilePath, {
          folder: "damanah_contracts",
          resource_type: "auto",
          public_id: `contract_${contract._id}`,
          access_mode: "public",
        });

        // حفظ الرابط
        contract.contractFile = uploadResult.secure_url;
        await contract.save();

        // حذف الملف المؤقت
        if (fs.existsSync(tempFilePath)) {
          fs.unlinkSync(tempFilePath);
        }
      }
    } catch (pdfError) {
      // ⚠️ في حال فشل الـ PDF، نسجل الخطأ ولكن لا نوقف العملية
      console.error("⚠️ Warning: Contract PDF generation failed:", pdfError.message);
    }
    // =========================================================

    // 9) إشعار للعميل (اختياري)
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

    // 10) رجّع البيانات (نجاح العملية)
    return res.status(200).json({
      message: "Offer accepted and contract created",
      project,
      contract,
      pdfUrl: contract.contractFile || null,
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
    if (!req.file)
      return res.status(400).json({ message: "Plan file is required" });

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
// Estimate
// =======================
exports.estimateProject = async (req, res) => {
  try {
    const projectId = req.params.id || req.params.projectId;
    const selections = Array.isArray(req.body.selections)
      ? req.body.selections
      : [];

    const project = await Project.findById(projectId);
    if (!project) return res.status(404).json({ message: "Project not found" });

    if (!req.user?._id) return res.status(401).json({ message: "Unauthorized" });
    if (String(project.owner) !== String(req.user._id)) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    // ✅ التعديل الجوهري: تحديث بيانات المشروع بالقيم المعمارية الجديدة القادمة من الفرونت اند
    // لضمان أن دالة generateBoqForProject تستخدم أحدث الأرقام (المحيط، الارتفاع، إلخ)
    if (req.body.planAnalysis) {
      // ندمج البيانات الجديدة مع التحليل الموجود مسبقاً
      project.planAnalysis = {
        ...project.planAnalysis,
        ...req.body.planAnalysis,
        // نضمن تحديث الحقول الحساسة للحسابات
        wallPerimeterLinear: req.body.planAnalysis.wallPerimeter || project.planAnalysis.wallPerimeterLinear,
        ceilingHeight: req.body.planAnalysis.ceilingHeight || project.planAnalysis.ceilingHeight
      };
      
      // تحديث الحقول الأساسية إذا تم تعديلها في Step 2
      if (req.body.area) project.area = req.body.area;
      if (req.body.floors) project.floors = req.body.floors;
      
      // وسم المشروع بأنه تم تعديله يدوياً لضمان الدقة
      project.markModified('planAnalysis');
    }

    // استدعاء محرك الحسابات المطور
    const estimation = await generateBoqForProject(project, { 
      selections,
      buildingType: project.buildingType 
    });

    // حفظ التقدير والبيانات المحدثة
    project.estimation = estimation;
    await project.save();

    return res.json({
      message: "Estimate generated successfully",
      items: estimation.items,
      totalCost: estimation.totalCost,
      currency: estimation.currency,
      finishingLevel: project.finishingLevel,
      buildingType: estimation.buildingType,
      // نرسل المساحات المحسوبة للتأكيد في الواجهة
      metadata: estimation.metadata 
    });
  } catch (err) {
    console.error("estimateProject error:", err);
    return res
      .status(500)
      .json({ message: "Estimate failed", error: err.message });
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
    return res
      .status(500)
      .json({ message: "Save failed", error: err.message });
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

    const estimation = project.estimation || {
      items: [],
      totalCost: 0,
      currency: "JOD",
    };
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
// Share
// =======================
exports.shareProject = async (req, res) => {
  try {
    const { contractorId } = req.body;
    if (!contractorId)
      return res.status(400).json({ message: "contractorId is required" });

    const project = await Project.findById(req.params.id);
    if (!project) return res.status(404).json({ message: "Project not found" });
    if (String(project.owner) !== String(req.user._id)) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    const contractor = await Contractor.findById(contractorId)
      .select("name isActive role")
      .lean();
    if (!contractor || contractor.role !== "contractor")
      return res.status(404).json({ message: "Contractor not found" });
    if (!contractor.isActive)
      return res.status(400).json({ message: "Contractor is not active" });

    project.sharedWithModel = "Contractor";
    project.sharedWith = project.sharedWith || [];
    const exists = project.sharedWith.some(
      (id) => String(id) === String(contractorId)
    );
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
    return res
      .status(500)
      .json({ message: "Share failed", error: err.message });
  }
};

// =======================
// Assign
// =======================
exports.assignContractor = async (req, res) => {
  try {
    const { contractorId } = req.body;
    if (!contractorId)
      return res.status(400).json({ message: "contractorId is required" });

    const project = await Project.findById(req.params.id);
    if (!project) return res.status(404).json({ message: "Project not found" });
    if (String(project.owner) !== String(req.user._id)) {
      return res.status(403).json({ message: "Not owner of this project" });
    }

    const contractor = await Contractor.findById(contractorId)
      .select("name isActive role")
      .lean();
    if (!contractor || contractor.role !== "contractor")
      return res.status(404).json({ message: "Contractor not found" });
    if (!contractor.isActive)
      return res.status(400).json({ message: "Contractor is not active" });

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
    return res
      .status(500)
      .json({ message: "Assign failed", error: err.message });
  }
};
// =======================
// Get Recent Offers across all projects (Client Dashboard)
// =======================
exports.getClientRecentOffers = async (req, res) => {
  try {
    // 1. جلب مشاريع المستخدم مع العروض وتفاصيل المقاول
    const projects = await Project.find({ owner: req.user._id })
      .select("title offers")
      .populate({
        path: "offers.contractor",
        select: "name profileImage",
      });

    // 2. تجميع العروض في قائمة واحدة مسطحة
    let allOffers = [];
    projects.forEach((project) => {
      if (project.offers && project.offers.length > 0) {
        project.offers.forEach((offer) => {
          allOffers.push({
            offerId: offer._id,
            price: offer.price,
            message: offer.message,
            createdAt: offer.createdAt, // تاريخ العرض
            contractorName: offer.contractor ? offer.contractor.name : "Unknown",
            contractorImage: offer.contractor ? offer.contractor.profileImage : null,
            projectTitle: project.title, // اسم المشروع
            projectId: project._id,
          });
        });
      }
    });

    // 3. ترتيبها من الأحدث للأقدم
    allOffers.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    // 4. إرجاع أول 5 عروض فقط
    return res.json(allOffers.slice(0, 5));
  } catch (err) {
    console.error("getClientRecentOffers error:", err);
    return res.status(500).json({ error: err.message });
  }
};

// =======================
// Client - My Contractors (ONLY RELATED)
// =======================
exports.getMyContractors = async (req, res) => {
  try {
    const clientId = req.user._id;

    // 1. جلب مشاريع العميل التي لها مقاول
    const projects = await Project.find({
      owner: clientId,
      contractor: { $ne: null },
    })
      .select("contractor")
      .populate("contractor", "name email phone profileImage contractorStatus isActive");

    // 2. استخراج المقاولين بدون تكرار
    const contractorsMap = new Map();

    projects.forEach((p) => {
      if (p.contractor) {
        contractorsMap.set(
          p.contractor._id.toString(),
          p.contractor
        );
      }
    });

    const contractors = Array.from(contractorsMap.values());

    return res.json(contractors);
  } catch (err) {
    console.error("getMyContractors error:", err);
    return res.status(500).json({ message: "Server error" });
  }
};
// =======================
// Contractor - My Submitted Offers (across all projects)
// GET /api/projects/contractor/my-offers
// =======================
exports.getContractorMyOffers = async (req, res) => {
  try {
    const contractorId = req.user._id.toString();

    // نجيب المشاريع اللي فيها offer للمقاول الحالي
    const projects = await Project.find({
      "offers.contractor": req.user._id,
    })
      .select("title offers createdAt")
      .populate({
        path: "owner",
        select: "name profileImage",
      })
      .populate({
        path: "offers.contractor",
        select: "name profileImage",
      })
      .sort({ createdAt: -1 });

    const baseUrl = getBaseUrl(req);

    const myOffers = [];

    projects.forEach((project) => {
      const p = project.toObject();

      // owner image full url (اختياري)
      if (p.owner && p.owner.profileImage) {
        p.owner.profileImage = p.owner.profileImage.startsWith("http")
          ? p.owner.profileImage
          : `${baseUrl}${p.owner.profileImage.replaceAll("\\", "/")}`;
      }

      (p.offers || []).forEach((offer) => {
        // بس عروض المقاول الحالي
        const offerContractorId =
          offer.contractor && offer.contractor._id
            ? offer.contractor._id.toString()
            : offer.contractor?.toString();

        if (offerContractorId !== contractorId) return;

        myOffers.push({
          offerId: offer._id,
          projectId: p._id,
          projectTitle: p.title,

          price: offer.price,
          message: offer.message || "",
          status: offer.status || "pending",
          createdAt: offer.createdAt,

          // معلومات صاحب المشروع (للواجهة إذا بدك)
          ownerName: p.owner?.name || "Unknown",
          ownerImage: p.owner?.profileImage || null,
        });
      });
    });

    // ترتيب من الأحدث للأقدم
    myOffers.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    return res.json(myOffers);
  } catch (err) {
    console.error("getContractorMyOffers error:", err);
    return res.status(500).json({ message: "Server error", error: err.message });
  }
};

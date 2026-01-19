const path = require("path");
const fs = require("fs");
const mongoose = require("mongoose");

const Contract = require("../models/Contract");

const generateContractPdf = require("../utils/pdf/generateContractPdf");
const cloudinary = require("cloudinary").v2; // ✅ نستخدم مكتبة Cloudinary مباشرة للرفع اليدوي

// ========================
// Helpers
// ========================
function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function safeId(id) {
  return mongoose.Types.ObjectId.isValid(id);
}

// ========================
// GET /api/contracts
// ========================
exports.getMyContracts = async (req, res) => {
  try {
    // حسب نظامك: إذا المستخدم "Contractor" أو "Client" غيّر الفلترة
    const contracts = await Contract.find({
      $or: [{ contractor: req.user._id }, { client: req.user._id }],
    })
      .sort({ createdAt: -1 })
      .populate("project")
      .populate("client")
      .populate("contractor");

    return res.json({ success: true, data: contracts });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// ========================
// GET /api/contracts/:id
// ========================
exports.getContractById = async (req, res) => {
  try {
    const { id } = req.params;
    if (!safeId(id)) return res.status(400).json({ success: false, message: "Invalid id" });

    const contract = await Contract.findById(id)
      .populate("project")
      .populate("client")
      .populate("contractor");

    if (!contract) return res.status(404).json({ success: false, message: "Contract not found" });

    // (اختياري) تحقق صلاحيات الوصول
    const userId = String(req.user._id);
    const isAllowed =
      String(contract.client?._id) === userId || String(contract.contractor?._id) === userId;

    if (!isAllowed) return res.status(403).json({ success: false, message: "Forbidden" });

    return res.json({ success: true, data: contract });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// ========================
// POST /api/contracts
// Create + Generate PDF
// ========================
exports.createContract = async (req, res) => {
  try {
    const {
      project,
      client,
      contractor,
      agreedPrice,
      durationMonths,
      paymentTerms,
      projectDescription,
      materialsAndServices,
      terms,
      startDate,
      endDate,
    } = req.body;

    if (!project || !client || !contractor || agreedPrice == null) {
      return res.status(400).json({
        success: false,
        message: "project, client, contractor, agreedPrice are required",
      });
    }

    // 1) Create in DB
    const created = await Contract.create({
      project,
      client,
      contractor,
      agreedPrice,
      durationMonths: durationMonths ?? null,
      paymentTerms: paymentTerms ?? "",
      projectDescription: projectDescription ?? "",
      materialsAndServices: Array.isArray(materialsAndServices)
        ? materialsAndServices
        : [],
      terms: terms ?? "",
      startDate: startDate ?? undefined,
      endDate: endDate ?? null,
      status: "active",
    });

    // 2) Populate
    const contract = await Contract.findById(created._id)
      .populate("project")
      .populate("client")
      .populate("contractor");

    // 3) Generate PDF Locally (Temporary)
    // ✅ نستخدم مجلد os.tmpdir() لأنه المجلد الوحيد المسموح بالكتابة فيه في Render
    const tempDir = os.tmpdir();
    const fileName = `contract-${contract._id}.pdf`;
    const tempFilePath = path.join(tempDir, fileName);

    // هذه الدالة ستنشئ الملف وتحفظه في tempFilePath
    await generateContractPdf(contract, tempFilePath);

    // 4) Upload to Cloudinary manually
    // ✅ نرفع الملف الذي أنشأناه للتو
    const uploadResult = await cloudinary.uploader.upload(tempFilePath, {
      folder: "damanah_contracts", // اسم المجلد في Cloudinary
      resource_type: "auto", // ليقبل PDF
      public_id: `contract_${contract._id}`, // اسم الملف في الكلاود
      access_mode: "public", // ليكون قابلاً للتحميل
    });

    // 5) Save Cloudinary URL in DB
    contract.contractFile = uploadResult.secure_url;
    await contract.save();

    // 6) Clean up: Delete local temp file (مهم جداً لتوفير المساحة)
    if (fs.existsSync(tempFilePath)) {
      fs.unlinkSync(tempFilePath);
    }

    return res.status(201).json({
      success: true,
      data: contract,
      pdfUrl: contract.contractFile, // الرابط الجديد (Cloudinary)
    });
  } catch (err) {
    console.error("Create Contract Error:", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
// ========================
// GET /api/contracts/:id/pdf
// Download/Preview PDF
// ========================
exports.getContractPdf = async (req, res) => {
  try {
    const { id } = req.params;
    if (!safeId(id)) return res.status(400).json({ success: false, message: "Invalid id" });

    const contract = await Contract.findById(id)
      .populate("project")
      .populate("client")
      .populate("contractor");

    if (!contract) return res.status(404).json({ success: false, message: "Contract not found" });

    // صلاحيات الوصول
    const userId = String(req.user._id);
    const isAllowed =
      String(contract.client?._id) === userId || String(contract.contractor?._id) === userId;

    if (!isAllowed) return res.status(403).json({ success: false, message: "Forbidden" });

    if (!contract.contractFile) {
      return res.status(404).json({ success: false, message: "PDF not generated yet" });
    }

    const absPath = path.join(__dirname, "..", contract.contractFile); // /uploads/...
    if (!fs.existsSync(absPath)) {
      return res.status(404).json({ success: false, message: "PDF file missing on server" });
    }

    // عرض/تحميل
    res.setHeader("Content-Type", "application/pdf");
    // inline للعرض في المتصفح، attachment للتنزيل
    res.setHeader("Content-Disposition", `inline; filename="contract-${id}.pdf"`);

    return fs.createReadStream(absPath).pipe(res);
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

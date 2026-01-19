const path = require("path");
const fs = require("fs");
const mongoose = require("mongoose");

const Contract = require("../models/Contract");

const generateContractPdf = require("../utils/pdf/generateContractPdf");

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
      materialsAndServices: Array.isArray(materialsAndServices) ? materialsAndServices : [],
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

    // (اختياري) صلاحيات: مثال إذا فقط المقاول ينشئ عقد
    // لو بدك: تحقق من req.user._id == contractor
    // if (String(req.user._id) !== String(contractor)) return res.status(403)...

    // 3) Generate PDF
    const uploadsDir = path.join(__dirname, "..", "uploads");
    const contractsDir = path.join(uploadsDir, "contracts");
    ensureDir(contractsDir);

    const fileName = `contract-${contract._id}.pdf`;
    const absPdfPath = path.join(contractsDir, fileName);

    await generateContractPdf(contract, absPdfPath);

    // 4) Save path in DB (موجود عندك contractFile) :contentReference[oaicite:3]{index=3}
    contract.contractFile = `/uploads/contracts/${fileName}`;
    await contract.save();

    return res.status(201).json({
      success: true,
      data: contract,
      pdfUrl: contract.contractFile,
    });
  } catch (err) {
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

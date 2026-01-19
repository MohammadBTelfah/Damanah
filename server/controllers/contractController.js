const path = require("path");
const fs = require("fs");
const os = require("os");
const mongoose = require("mongoose");
const cloudinary = require("cloudinary").v2;

const Contract = require("../models/Contract");
const generateContractPdf = require("../utils/pdf/generateContractPdf");

// ========================
// Helpers
// ========================
function safeId(id) {
  return mongoose.Types.ObjectId.isValid(id);
}

// ========================
// GET /api/contracts
// ✅ Get My Contracts (Client OR Contractor)
// ========================
exports.getMyContracts = async (req, res) => {
  try {
    if (!req.user || !req.user._id) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const userId = req.user._id;

    // ✅ يطلع العقد لو المستخدم هو العميل أو المقاول
    const contracts = await Contract.find({
      $or: [{ client: userId }, { contractor: userId }],
    })
      .populate("project")
      .populate("client")
      .populate("contractor")
      .sort({ createdAt: -1 });

    return res.status(200).json({ contracts });
  } catch (err) {
    console.error("getMyContracts error:", err);
    return res
      .status(500)
      .json({ message: "Server error", error: err.message });
  }
};

// ========================
// GET /api/contracts/:id
// ========================
exports.getContractById = async (req, res) => {
  try {
    const { id } = req.params;
    if (!safeId(id)) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid id" });
    }

    const contract = await Contract.findById(id)
      .populate("project")
      .populate("client")
      .populate("contractor");

    if (!contract) {
      return res
        .status(404)
        .json({ success: false, message: "Contract not found" });
    }

    // ✅ صلاحيات الوصول: عميل أو مقاول
    const userId = String(req.user._id);
    const isAllowed =
      String(contract.client?._id) === userId ||
      String(contract.contractor?._id) === userId;

    if (!isAllowed) {
      return res
        .status(403)
        .json({ success: false, message: "Forbidden" });
    }

    return res.json({ success: true, data: contract });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// ========================
// POST /api/contracts
// Create + Generate PDF + Upload Cloudinary
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

    // ✅ (اختياري لكن مهم) منع عقدين لنفس المشروع
    const existing = await Contract.findOne({ project });
    if (existing) {
      return res.status(200).json({
        success: true,
        message: "Contract already exists for this project",
        data: existing,
        pdfUrl: existing.contractFile || null,
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

    // 3) Generate PDF Locally (Temporary) in os.tmpdir()
    const tempDir = os.tmpdir();
    const fileName = `contract-${contract._id}.pdf`;
    const tempFilePath = path.join(tempDir, fileName);

    await generateContractPdf(contract, tempFilePath);

    // 4) Upload to Cloudinary manually
    const uploadResult = await cloudinary.uploader.upload(tempFilePath, {
      folder: "damanah_contracts",
      resource_type: "auto",
      public_id: `contract_${contract._id}`,
      access_mode: "public",
    });

    // 5) Save Cloudinary URL in DB
    contract.contractFile = uploadResult.secure_url;
    await contract.save();

    // 6) Clean up temp file
    try {
      if (fs.existsSync(tempFilePath)) fs.unlinkSync(tempFilePath);
    } catch (e) {
      console.warn("temp pdf cleanup failed:", e.message);
    }

    return res.status(201).json({
      success: true,
      data: contract,
      pdfUrl: contract.contractFile,
    });
  } catch (err) {
    console.error("Create Contract Error:", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

// ========================
// GET /api/contracts/:id/pdf
// ✅ Redirect to Cloudinary PDF
// ========================
exports.getContractPdf = async (req, res) => {
  try {
    const { id } = req.params;
    if (!safeId(id)) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid id" });
    }

    const contract = await Contract.findById(id)
      .populate("project")
      .populate("client")
      .populate("contractor");

    if (!contract) {
      return res
        .status(404)
        .json({ success: false, message: "Contract not found" });
    }

    // ✅ صلاحيات الوصول
    const userId = String(req.user._id);
    const isAllowed =
      String(contract.client?._id) === userId ||
      String(contract.contractor?._id) === userId;

    if (!isAllowed) {
      return res
        .status(403)
        .json({ success: false, message: "Forbidden" });
    }

    if (!contract.contractFile) {
      return res
        .status(404)
        .json({ success: false, message: "PDF not generated yet" });
    }

    // ✅ لأنه URL على Cloudinary
    return res.redirect(contract.contractFile);
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

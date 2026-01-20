const mongoose = require("mongoose"); // ✅ ضروري للدالة safeId
const fs = require("fs");
const path = require("path");
const os = require("os");
const Contract = require("../models/Contract");
const generateContractPdf = require("../utils/pdf/generateContractPdf");
const Project = require("../models/Project");

// ✅ تصحيح: استدعاء ملف الإعدادات الذي يحتوي على مكتبة Cloudinary الأصلية
const cloudinary = require("../config/cloudinaryConfig"); 

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
      project: projectId,
      client,
      contractor,
      agreedPrice,
      durationMonths,
      paymentTerms,
      projectDescription,
      terms,
      startDate,
      endDate
    } = req.body;

    // 1. جلب المشروع للوصول إلى تفاصيل التقدير (Estimation)
    const projectData = await Project.findById(projectId);

    if (!projectData) {
      return res.status(404).json({ message: "Project not found" });
    }

    // 2. تجهيز قائمة المواد تلقائياً من المشروع
    let finalMaterials = [];

    if (req.body.materialsAndServices && req.body.materialsAndServices.length > 0) {
      finalMaterials = req.body.materialsAndServices;
    } else if (projectData.estimation && projectData.estimation.items) {
      finalMaterials = projectData.estimation.items.map(item => {
        return `${item.name} (الكمية: ${item.quantity} ${item.unit || ''})`;
      });
    }

    // 3. إنشاء العقد مع المواد المجهزة
    const newContract = await Contract.create({
      project: projectId,
      client,
      contractor,
      agreedPrice,
      durationMonths,
      paymentTerms,
      projectDescription,
      materialsAndServices: finalMaterials,
      terms,
      startDate,
      endDate,
      status: "active"
    });

    // 4. ✅ جلب بيانات الهوية والرقم الوطني + الاسم الرسمي fullNameFromId للطباعة
    const populatedContract = await Contract.findById(newContract._id)
      .populate("project")
      .populate("client", "name fullNameFromId identityData nationalId phone email address city")
      .populate("contractor", "name fullNameFromId identityData nationalId phone email address city");

    // 5. توليد الـ PDF
    const tempDir = os.tmpdir();
    const pdfName = `contract-${newContract._id}.pdf`;
    const tempFilePath = path.join(tempDir, pdfName);

    await generateContractPdf(populatedContract, tempFilePath);

    // 6. الرفع إلى Cloudinary
    const uploadResult = await cloudinary.uploader.upload(tempFilePath, {
      folder: "damanah_contracts",
      resource_type: "raw",
      access_mode: "public",
      public_id: `contract_${newContract._id}`,
    });

    populatedContract.contractFile = uploadResult.secure_url;
    await populatedContract.save();

    if (fs.existsSync(tempFilePath)) fs.unlinkSync(tempFilePath);

    return res.status(201).json({
      success: true,
      message: "Contract created successfully",
      contract: populatedContract,
      pdfUrl: populatedContract.contractFile
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
const mongoose = require("mongoose"); // ✅ ضروري للدالة safeId
const fs = require("fs");
const path = require("path");
const os = require("os");
const Contract = require("../models/Contract");
const generateContractPdf = require("../utils/pdf/generateContractPdf");

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
    // استقبال البيانات من الـ Body
    const {
      project, client, contractor, agreedPrice, durationMonths,
      paymentTerms, projectDescription, materialsAndServices,
      terms, startDate, endDate
    } = req.body;

    // التحقق من البيانات الأساسية
    if (!project || !client || !contractor || agreedPrice == null) {
      return res.status(400).json({ message: "Missing required fields" });
    }

    // 1. إنشاء العقد في قاعدة البيانات
    const newContract = await Contract.create({
      project, client, contractor, agreedPrice,
      durationMonths, paymentTerms, projectDescription,
      materialsAndServices, terms, startDate, endDate,
      status: "active"
    });

    // 2. جلب بيانات العقد كاملة (Populate) لملء القالب
    const populatedContract = await Contract.findById(newContract._id)
      .populate("project") // لجلب اسم المشروع وموقعه
      .populate("client")  // لجلب اسم العميل وهاتفه
      .populate("contractor"); // لجلب اسم المقاول وهاتفه

    // 3. تحديد مسار مؤقت للملف
    const tempDir = os.tmpdir();
    const pdfName = `contract-${newContract._id}.pdf`;
    const tempFilePath = path.join(tempDir, pdfName);

    // 4. استدعاء الدالة التي تملأ القالب وتنشئ الـ PDF
    await generateContractPdf(populatedContract, tempFilePath);

    // 5. رفع الملف الناتج إلى Cloudinary
    // ✅ الآن المتغير cloudinary يحتوي على المكتبة الصحيحة ولن يعطي خطأ undefined
    const uploadResult = await cloudinary.uploader.upload(tempFilePath, {
      folder: "damanah_contracts",
      resource_type: "auto", // يفضل auto ليتعرف عليه سواء كان pdf أو صورة
      access_mode: "public",
      public_id: `contract_${newContract._id}`, // اسم ثابت للملف لتسهيل الوصول
    });

    // 6. حفظ الرابط في العقد وحذف الملف المؤقت
    populatedContract.contractFile = uploadResult.secure_url;
    await populatedContract.save();

    if (fs.existsSync(tempFilePath)) fs.unlinkSync(tempFilePath);

    // 7. الرد بالرابط (هنا يتم نقلك لفتح القالب المعبأ)
    return res.status(201).json({
      success: true,
      message: "Contract created and PDF generated successfully",
      contract: populatedContract,
      pdfUrl: populatedContract.contractFile // هذا الرابط هو القالب المعبأ
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
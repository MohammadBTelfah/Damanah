const Contract = require("../models/Contract");

// ✅ جلب العقود الخاصة بالمستخدم (سواء كان عميل أو مقاول)
exports.getMyContracts = async (req, res) => {
  try {
    if (!req.user || !req.user._id) {
      return res.status(401).json({ message: "Not authenticated" });
    }

    const userId = req.user._id;

    // البحث عن العقود التي يكون فيها المستخدم هو الـ client أو الـ contractor
    const contracts = await Contract.find({
      $or: [{ client: userId }, { contractor: userId }],
    })
      .populate("project", "title location status") // تفاصيل المشروع
      .populate("client", "name email phone profileImage") // تفاصيل العميل
      .populate("contractor", "name email phone profileImage") // تفاصيل المقاول
      .sort({ createdAt: -1 }); // الأحدث أولاً

    return res.json(contracts);
  } catch (err) {
    console.error("getMyContracts error:", err);
    return res.status(500).json({ message: "Failed to fetch contracts" });
  }
};

// ✅ جلب تفاصيل عقد معين
exports.getContractById = async (req, res) => {
  try {
    const contract = await Contract.findById(req.params.id)
      .populate("project")
      .populate("client", "name email phone profileImage")
      .populate("contractor", "name email phone profileImage");

    if (!contract) {
      return res.status(404).json({ message: "Contract not found" });
    }

    // التحقق من الصلاحية (يجب أن يكون المستخدم طرفاً في العقد)
    const userId = String(req.user._id);
    const clientId = String(contract.client._id);
    const contractorId = String(contract.contractor._id);

    if (userId !== clientId && userId !== contractorId) {
      return res.status(403).json({ message: "Not authorized to view this contract" });
    }

    return res.json(contract);
  } catch (err) {
    console.error("getContractById error:", err);
    return res.status(500).json({ message: "Server error" });
  }
};
const Material = require("../models/Material");

// ======================
// Helpers
// ======================
function approximatePerimeterFromArea(area) {
  if (!area || area <= 0) return 0;
  const side = Math.sqrt(area);
  return 4 * side;
}

/**
 * Normalize buildingType
 */
function normalizeBuildingType(t) {
  const v = String(t || "").trim().toLowerCase();
  if (v === "house") return "House";
  if (v === "villa") return "Villa";
  if (v === "commercial") return "Commercial";
  return "House";
}

function pickVariantByKey(materialDoc, variantKey) {
  if (!materialDoc || !variantKey) return null;
  const vars = Array.isArray(materialDoc.variants) ? materialDoc.variants : [];
  return vars.find((x) => String(x.key) === String(variantKey)) || null;
}

function buildItem(name, unit, quantity, pricePerUnit, meta = {}, variantLabel = "") {
  const q = Number(quantity || 0);
  const p = Number(pricePerUnit || 0);
  return {
    name,
    quantity: Number(q.toFixed(2)),
    unit,
    pricePerUnit: p,
    total: Number((q * p).toFixed(2)),
    variantLabel,
    ...meta,
  };
}

// ======================
// Presets
// ======================
const PRESETS = {
  House: {
    height: 3.0,
    waste: 1.05,
    wall_factor: 0.85, // نسبة الجدران للمحيط
    window_ratio: 0.15, // نسبة الشبابيك من الجدران
    door_ratio: 0.05,   // نسبة الأبواب
  },
  Villa: {
    height: 3.2,
    waste: 1.07,
    wall_factor: 1.0,
    window_ratio: 0.20,
    door_ratio: 0.06,
  },
  Commercial: {
    height: 3.5,
    waste: 1.08,
    wall_factor: 1.1,
    window_ratio: 0.25,
    door_ratio: 0.04,
  },
};

// ======================
// Main Logic
// ======================
async function generateBoqForProject(project, options = {}) {
  const area = Number(project.area || 0);
  const floors = Math.max(1, Number(project.floors || 1));
  const rooms = Math.max(1, Number(project.planAnalysis?.rooms || 3)); 
  const bathrooms = Math.max(1, Number(project.planAnalysis?.bathrooms || 1));

  const buildingType = normalizeBuildingType(
    options.buildingType || project.buildingType || "House"
  );

  const preset = PRESETS[buildingType] || PRESETS.House;
  const height = preset.height;
  const waste = preset.waste;

  // 1. حسابات هندسية أساسية
  const totalFloorArea = area * floors; // المساحة الإجمالية للطوابق
  const perimeter = approximatePerimeterFromArea(area);
  const totalWallArea = perimeter * height * floors * preset.wall_factor; // مساحة الجدران التقريبية
  const roofArea = area; // مساحة السطح (للعزل)

  // ======================
  // Selections Processing
  // ======================
  const selections = Array.isArray(options.selections) ? options.selections : [];

  if (selections.length === 0) {
    return { items: [], totalCost: 0, currency: "JOD", buildingType, error: "No materials selected" };
  }

  // جلب المواد المختارة فقط من قاعدة البيانات
  const selectedById = new Map(
    selections
      .filter((s) => s?.materialId && s?.variantKey)
      .map((s) => [String(s.materialId), String(s.variantKey)])
  );

  const mats = await Material.find({
    _id: { $in: [...selectedById.keys()] },
  }).lean();

  const items = [];

  // ======================
  // Loop through selected materials only
  // ======================
  for (const mat of mats) {
    const variantKey = selectedById.get(String(mat._id));
    const variant = pickVariantByKey(mat, variantKey);
    
    if (!variant) continue; // تخطي إذا لم يتم العثور على النوع

    const nameLower = mat.name.toLowerCase();
    let calculatedQty = 0;
    let unit = mat.unit || variant.unit || "Piece";

    // ----------------------------------------------------
    // 🧠 منطق الحساب الذكي لكل مادة
    // ----------------------------------------------------

    // 1. الهيكل الأسود (Bone / Structure)
    if (nameLower.includes("cement") || nameLower.includes("أسمنت")) {
      // الأسمنت: تقريباً 0.35 طن لكل متر مربع بناء
      calculatedQty = totalFloorArea * 0.35 * waste;
      unit = "Ton";
    } 
    else if (nameLower.includes("steel") || nameLower.includes("rebar") || nameLower.includes("حديد")) {
      // الحديد: تقريباً 50 كغم لكل متر مربع
      calculatedQty = (totalFloorArea * 50 / 1000) * waste; 
      unit = "Ton";
    }
    else if (nameLower.includes("sand") || nameLower.includes("رمل")) {
      // الرمل: تقريباً 0.15 متر مكعب لكل متر مربع
      calculatedQty = totalFloorArea * 0.15 * waste;
      unit = "m3";
    }
    else if (nameLower.includes("aggregate") || nameLower.includes("حصمة")) {
      // الحصمة: تقريباً 0.12 متر مكعب لكل متر مربع
      calculatedQty = totalFloorArea * 0.12 * waste;
      unit = "m3";
    }
    else if (nameLower.includes("hollow block") || nameLower.includes("طوب")) {
      // الطوب: يعتمد على مساحة الجدران (12.5 طوبة للمتر)
      calculatedQty = totalWallArea * 12.5 * waste;
      unit = "Piece";
    }

    // 2. التشطيبات الداخلية (Internal Finishes)
    else if (nameLower.includes("porcelain") || nameLower.includes("بورسلان") || 
             nameLower.includes("marble") || nameLower.includes("رخام")) {
      // بلاط الأرضيات: المساحة + الهدر
      calculatedQty = totalFloorArea * waste;
      unit = "m2";
    }
    else if (nameLower.includes("paint") || nameLower.includes("دهان")) {
      // الدهان: مساحة الجدران + السقف (تقريباً 3 أضعاف مساحة الأرضية)
      const paintArea = (totalWallArea + totalFloorArea);
      // الفرضية: الجالون يغطي 30 متر وجهين
      calculatedQty = (paintArea / 30) * waste;
      unit = "Gallon";
    }
    else if (nameLower.includes("gypsum") || nameLower.includes("جبس")) {
      // الجبس: مساحة الأسقف (نفس مساحة الأرضية)
      calculatedQty = totalFloorArea * waste;
      unit = "Board"; // أو m2 حسب الوحدة
    }
    else if (nameLower.includes("internal door") || nameLower.includes("أبواب داخلية")) {
      // الأبواب الداخلية: عدد الغرف + الحمامات
      calculatedQty = rooms + bathrooms;
      unit = "Piece";
    }
    else if (nameLower.includes("sanitary") || nameLower.includes("أطقم حمامات")) {
      // أطقم الحمامات: عدد الحمامات
      calculatedQty = bathrooms;
      unit = "Piece";
    }
    else if (nameLower.includes("electrical switch") || nameLower.includes("أفياش")) {
      // الأفياش: تقريباً 4 لكل غرفة
      calculatedQty = (rooms * 4 + bathrooms * 2 + (totalFloorArea / 20)) * waste; 
      unit = "Piece";
    }
    else if (nameLower.includes("lighting") || nameLower.includes("إنارة")) {
      // الإنارة: تقريباً نقطة لكل 10 متر مربع
      calculatedQty = (totalFloorArea / 10) * waste;
      unit = "Piece";
    }
    else if (nameLower.includes("kitchen") || nameLower.includes("مطبخ")) {
      // المطبخ: تقديري 4-6 متر طولي لكل شقة/طابق
      calculatedQty = 5 * floors; 
      unit = "Linear Meter";
    }
    else if (nameLower.includes("heating") || nameLower.includes("تدفئة")) {
      // التدفئة: كامل المساحة
      calculatedQty = totalFloorArea;
      unit = "m2";
    }

    // 3. التشطيبات الخارجية (External)
    else if (nameLower.includes("stone") || nameLower.includes("حجر")) {
      // حجر الواجهات: مساحة الجدران الخارجية
      calculatedQty = totalWallArea * waste;
      unit = "m2";
    }
    else if (nameLower.includes("aluminum") || nameLower.includes("شبابيك")) {
      // الشبابيك: نسبة من مساحة الجدران
      calculatedQty = totalWallArea * preset.window_ratio;
      unit = "m2";
    }
    else if (nameLower.includes("shutter") || nameLower.includes("أباجورات")) {
      // الأباجورات: نفس مساحة الشبابيك
      calculatedQty = totalWallArea * preset.window_ratio;
      unit = "m2";
    }
    else if (nameLower.includes("main door") || nameLower.includes("باب أمان")) {
      // باب رئيسي لكل طابق (أو شقة)
      calculatedQty = floors;
      unit = "Piece";
    }
    else if (nameLower.includes("roof insulation") || nameLower.includes("عزل أسطح")) {
      // عزل السطح: مساحة المسقط الأفقي فقط
      calculatedQty = roofArea * waste;
      unit = "m2";
    }
    else if (nameLower.includes("water tank") || nameLower.includes("خزانات")) {
      // خزانات مياه: 1-2 لكل طابق
      calculatedQty = 2 * floors;
      unit = "Piece";
    }
    else if (nameLower.includes("interlock") || nameLower.includes("انترلوك")) {
      // الساحات الخارجية: تقديرياً نصف مساحة الأرض (أو حسب المدخل)
      // سنفترض 20% من المساحة كممرات
      calculatedQty = area * 0.20 * waste; 
      unit = "m2";
    }
    
    // 4. Fallback (أي مادة أخرى)
    else {
      // افتراض كمية 1 إذا لم نعرف المعادلة
      calculatedQty = 1; 
    }

    // إضافة البند للقائمة
    if (calculatedQty > 0) {
      items.push(
        buildItem(
          mat.name,
          unit,
          calculatedQty,
          variant.pricePerUnit,
          { materialId: mat._id, variantKey: variant.key },
          variant.label || variant.key
        )
      );
    }
  }

  const totalCost = items.reduce((s, i) => s + i.total, 0);

  return {
    items,
    totalCost: Number(totalCost.toFixed(2)),
    currency: "JOD",
    buildingType,
  };
}

module.exports = { generateBoqForProject, PRESETS };
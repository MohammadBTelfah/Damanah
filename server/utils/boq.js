const Material = require("../models/Material");

// ======================
// Helpers (المساعدات الهندسية)
// ======================

/**
 * حساب محيط الجدران بناءً على المساحة (في حال عدم وجود طول جدران دقيق من الـ AI)
 */
function approximatePerimeterFromArea(area) {
  if (!area || area <= 0) return 0;
  const side = Math.sqrt(area);
  return 4 * side;
}

/**
 * تنميط نوع البناء
 */
function normalizeBuildingType(t) {
  const v = String(t || "").trim().toLowerCase();
  if (v === "house") return "House";
  if (v === "villa") return "Villa";
  if (v === "commercial") return "Commercial";
  return "House";
}

/**
 * اختيار النوع المختار للمادة (Basic, Medium, Premium)
 */
function pickVariantByKey(materialDoc, variantKey) {
  if (!materialDoc || !variantKey) return null;
  const vars = Array.isArray(materialDoc.variants) ? materialDoc.variants : [];
  return vars.find((x) => String(x.key) === String(variantKey)) || null;
}

/**
 * بناء غرض البند النهائي في جدول الكميات
 */
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
// Presets (المعايير الهندسية حسب نوع البناء)
// ======================
const PRESETS = {
  House: {
    height: 3.0,
    waste: 1.05,        // هدر 5%
    wall_factor: 0.85,  // نسبة الجدران الداخلية للمحيط
    window_ratio: 0.15, // نسبة الشبابيك الافتراضية
    door_ratio: 0.05,
  },
  Villa: {
    height: 3.2,
    waste: 1.07,        // هدر 7%
    wall_factor: 1.0,
    window_ratio: 0.20,
    door_ratio: 0.06,
  },
  Commercial: {
    height: 3.5,
    waste: 1.08,        // هدر 8%
    wall_factor: 1.1,
    window_ratio: 0.25,
    door_ratio: 0.04,
  },
};

// ======================
// Main Logic (توليد جدول الكميات BOQ)
// ======================
async function generateBoqForProject(project, options = {}) {
  // 1. استخراج البيانات الأساسية من المشروع
  const area = Number(project.area || 0);
  const floors = Math.max(1, Number(project.floors || 1));
  
  // بيانات الـ AI المتقدمة (Quantity Takeoff)
  const analysis = project.planAnalysis || {};
  const visionWindows = analysis.openings?.windows || {};
  const visionDoors = analysis.openings?.internalDoors || {};
  const visionVoids = analysis.openings?.voids || {}; // الفتحات المفقودة (المناور)
  
  const wallPerimeterAI = Number(analysis.wallPerimeterLinear || 0);
  const voidPerimeterAI = Number(visionVoids.voidPerimeter || 0);
  const voidAreaAI = Number(visionVoids.totalVoidArea || 0);
  
  // الارتفاع المعتمد (من المخطط أو الافتراضي)
  const ceilingHeight = Number(analysis.ceilingHeightDefault || project.ceilingHeight || 3.0);

  // إحصائيات الغرف
  const rooms = Math.max(1, Number(project.rooms || analysis.roomsCount || 3));
  const bathrooms = Math.max(1, Number(project.bathrooms || analysis.bathroomsCount || 1));

  const buildingType = normalizeBuildingType(options.buildingType || project.buildingType || "House");
  const preset = PRESETS[buildingType] || PRESETS.House;
  const waste = preset.waste;

  // 2. حسابات المساحات الهندسية الكلية (منطق الخصم والإضافة)
  
  // أ. مساحة الأرضية الصافية (Net Floor Area): خصم المناور من المساحة الكلية
  const netFloorArea = (area - voidAreaAI) * floors;

  // ب. حساب المحيط الكلي: محيط الجدران + محيط جدران المناور (فتحات مفقودة)
  const basePerimeter = wallPerimeterAI > 0 ? wallPerimeterAI : approximatePerimeterFromArea(area);
  const totalPerimeter = (basePerimeter + voidPerimeterAI);
  
  // ج. مساحة الجدران الكلية للدهان والتشطيب
  const totalWallArea = totalPerimeter * ceilingHeight * floors * preset.wall_factor;
  
  // د. مساحة السطح للعزل (المساحة الصافية بدون فتحات سماوية)
  const roofArea = area - voidAreaAI;

  // 3. معالجة الاختيارات
  const selections = Array.isArray(options.selections) ? options.selections : [];
  if (selections.length === 0) {
    return { items: [], totalCost: 0, currency: "JOD", buildingType, error: "No materials selected" };
  }

  const selectedById = new Map(
    selections
      .filter((s) => s?.materialId && s?.variantKey)
      .map((s) => [String(s.materialId), String(s.variantKey)])
  );

  const mats = await Material.find({
    _id: { $in: [...selectedById.keys()] },
  }).lean();

  const items = [];

  // 4. حلقة الحساب الذكي لكل مادة مختارة
  for (const mat of mats) {
    const variantKey = selectedById.get(String(mat._id));
    const variant = pickVariantByKey(mat, variantKey);
    if (!variant) continue;

    const nameLower = mat.name.toLowerCase();
    let calculatedQty = 0;
    let unit = mat.unit || variant.unit || "Piece";

    // ----------------------------------------------------
    // المعادلات الهندسية الدقيقة المحدثة
    // ----------------------------------------------------

    // أ. الهيكل الإنشائي (العظم) - يستخدم المساحة الصافية
    if (nameLower.includes("cement") || nameLower.includes("أسمنت")) {
      calculatedQty = netFloorArea * 0.40 * waste; 
      unit = "Ton";
    } 
    else if (nameLower.includes("steel") || nameLower.includes("حديد")) {
      calculatedQty = (netFloorArea * 65 / 1000) * waste; 
      unit = "Ton";
    }
    else if (nameLower.includes("hollow block") || nameLower.includes("طوب")) {
      // 12.5 طوبة لكل متر مربع جدار (شامل جدران المناور)
      calculatedQty = totalWallArea * 12.5 * waste;
      unit = "Piece";
    }

    // ب. التشطيبات الداخلية - منطق الخصم مطبق هنا
    else if (nameLower.includes("porcelain") || nameLower.includes("بورسلان") || nameLower.includes("tiles")) {
      calculatedQty = netFloorArea * 1.10 * waste; // بلاط للمساحة الصافية فقط
      unit = "m2";
    }
    else if (nameLower.includes("paint") || nameLower.includes("دهان")) {
      // مساحة الجدران (شاملة جدران المناور) + الأسقف الصافية
      const paintArea = (totalWallArea + netFloorArea);
      calculatedQty = (paintArea / 25) * waste; 
      unit = "Gallon";
    }
    else if (nameLower.includes("internal door") || nameLower.includes("أبواب داخلية")) {
      calculatedQty = visionDoors.count || (rooms + bathrooms);
      unit = "Piece";
    }

    // ج. الألمنيوم والأباجورات (Windows & Shutters)
    else if (nameLower.includes("aluminum") || nameLower.includes("شبابيك") || nameLower.includes("shutter") || nameLower.includes("أباجورات")) {
      if (visionWindows.totalArea > 0) {
        calculatedQty = visionWindows.totalArea * waste; 
      } else if (visionWindows.count > 0) {
        calculatedQty = visionWindows.count * 2.8 * waste; 
      } else {
        calculatedQty = totalWallArea * preset.window_ratio; 
      }
      unit = "m2";
    }

    // د. الأعمال الخارجية والعزل
    else if (nameLower.includes("stone") || nameLower.includes("حجر")) {
      calculatedQty = totalWallArea * 0.80 * waste; 
      unit = "m2";
    }
    else if (nameLower.includes("roof insulation") || nameLower.includes("عزل أسطح")) {
      calculatedQty = roofArea * waste; // عزل المساحة المسقوفة فقط
      unit = "m2";
    }
    else if (nameLower.includes("interlock") || nameLower.includes("انترلوك")) {
      calculatedQty = area * 0.35 * waste; 
      unit = "m2";
    }

    // هـ. الخدمات
    else if (nameLower.includes("water tank") || nameLower.includes("خزانات")) {
      calculatedQty = floors >= 2 ? 2 : 1; 
      unit = "Piece";
    }

    // Fallback العام
    else {
      calculatedQty = 1; 
    }

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
    metadata: {
      netCalculatedArea: netFloorArea,
      totalWallArea: totalWallArea,
      voidAreaSubtracted: voidAreaAI,
      isVisionBased: wallPerimeterAI > 0
    }
  };
}

module.exports = { generateBoqForProject, PRESETS };
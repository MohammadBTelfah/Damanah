const Material = require("../models/Material");

// ======================
// Helpers (كما هي)
// ======================
function approximatePerimeterFromArea(area) {
  if (!area || area <= 0) return 0;
  const side = Math.sqrt(area);
  return 4 * side;
}

function normalizeLevel(level) {
  const v = String(level || "").toLowerCase().trim();
  if (v === "basic") return "basic";
  if (v === "medium") return "medium";
  if (v === "premium") return "premium";
  if (v === "standard") return "medium";
  if (v === "luxury") return "premium";
  return "medium";
}

function normalizeBuildingType(t) {
  const v = String(t || "").toLowerCase().trim();
  if (["apartment", "villa", "commercial"].includes(v)) return v;
  if (v === "residential") return "apartment";
  if (v === "house") return "villa";
  if (v === "shop" || v === "office") return "commercial";
  return "apartment";
}

function pickVariantByKey(materialDoc, variantKey) {
  if (!materialDoc || !variantKey) return null;
  const vars = Array.isArray(materialDoc.variants) ? materialDoc.variants : [];
  return vars.find((x) => String(x.key) === String(variantKey)) || null;
}

function pickVariantByLevel(materialDoc, levelKey) {
  if (!materialDoc) return null;
  const vars = Array.isArray(materialDoc.variants) ? materialDoc.variants : [];
  const exact = vars.find((x) => x.key === levelKey);
  return exact || vars[0] || null;
}

function buildItem(name, unit, quantity, pricePerUnit, meta = {}) {
  const q = Number(quantity || 0);
  const p = Number(pricePerUnit || 0);
  return {
    name,
    quantity: Number(q.toFixed(2)),
    unit,
    pricePerUnit: p,
    total: Number((q * p).toFixed(2)),
    ...meta,
  };
}

// ======================
// Presets (كما هي)
// ======================
const PRESETS = {
  apartment: {
    label: "Apartment",
    height: 3.0,
    coats: 2,
    waste: 1.05,
    concrete_m3_per_m2: 0.11,
    rebar_kg_per_m2: 45,
    wall_exposure_factor: 0.85,
    tiles_floor_coverage: 0.75,
    plaster_wall_factor: 1.0,
    paint_factor: 0.85,
  },
  villa: {
    label: "Villa",
    height: 3.0,
    coats: 2,
    waste: 1.07,
    concrete_m3_per_m2: 0.12,
    rebar_kg_per_m2: 55,
    wall_exposure_factor: 1.0,
    tiles_floor_coverage: 0.85,
    plaster_wall_factor: 1.05,
    paint_factor: 0.9,
  },
  commercial: {
    label: "Commercial",
    height: 3.5,
    coats: 3,
    waste: 1.08,
    concrete_m3_per_m2: 0.14,
    rebar_kg_per_m2: 70,
    wall_exposure_factor: 1.1,
    tiles_floor_coverage: 0.6,
    plaster_wall_factor: 0.95,
    paint_factor: 0.8,
  },
};

// ======================
// Main Logic
// ======================
async function generateBoqForProject(project, options = {}) {
  const area = Number(project.area || 0);
  const floors = Math.max(1, Number(project.floors || 1));
  const levelKey = normalizeLevel(project.finishingLevel);

  const buildingType = normalizeBuildingType(
    options.buildingType || project.buildingType || "apartment"
  );

  const presetBase = PRESETS[buildingType] || PRESETS.apartment;
  const overrides =
    options.overrides && typeof options.overrides === "object"
      ? options.overrides
      : {};

  const preset = { ...presetBase, ...overrides };

  const height = Number(preset.height || 3);
  const coats = Number(preset.coats || 2);
  const waste = Number(preset.waste || 1.05);

  const selections = Array.isArray(options.selections) ? options.selections : [];
  const selectedById = new Map(
    selections
      .filter((s) => s && s.materialId && s.variantKey)
      .map((s) => [String(s.materialId), String(s.variantKey)])
  );

  // ✅ 1. تحديث قائمة المواد المطلوبة لتشمل المواد الجديدة
  // لاحظ: الأسماء هنا يجب أن تطابق حقل "name" في الداتا بيس بدقة (حسب الـ Bulk Import السابق)
  const neededNames = [
    "Concrete",
    "Steel Rebar",
    "Blocks",   // أو "Hollow Blocks" حسب التسمية عندك
    "Plaster",
    "Paint",    // أو "Internal Paint"
    "Tiles",    // أو "Porcelain Tiles"
    
    // --- المواد الجديدة ---
    "Sand",             // رمل
    "Aggregates",       // حصمة
    "Aluminum Windows", // شبابيك
    "Roller Shutters",  // أباجورات
    "Internal Doors",   // أبواب داخلية
    "Main Security Door", // باب رئيسي
    "Sanitary Ware",    // أطقم حمامات
    "Electrical Switches", // كهرباء
    "Water Tanks"       // خزانات
  ];

  const selectedIds = [
    ...new Set(
      selections
        .map((s) => (s && s.materialId ? String(s.materialId) : ""))
        .filter(Boolean)
    ),
  ];

  // البحث باستخدام Regex لجلب المواد حتى لو كان الاسم يختلف قليلاً (مثلاً "Sand (رمل)")
  const mats = await Material.find({
    $or: [
        // يبحث عن أي مادة اسمها يبدأ بهذه الكلمات
        { name: { $in: neededNames.map(n => new RegExp(n, "i")) } }, 
        { _id: { $in: selectedIds } }
    ],
  }).lean();

  // Helper للبحث في النتائج بمرونة
  const findMatByName = (partialName) => {
    return mats.find(m => m.name.toLowerCase().includes(partialName.toLowerCase()));
  };
  
  const byId = new Map(mats.map((m) => [String(m._id), m]));

  function chooseVariant(mat) {
    if (!mat) return null;
    const chosenKey = selectedById.get(String(mat._id));
    if (chosenKey) return pickVariantByKey(mat, chosenKey);
    return pickVariantByLevel(mat, levelKey);
  }

  const items = [];
  const perimeter = approximatePerimeterFromArea(area);
  const wallAreaBase = perimeter * height * floors;
  const wallArea = wallAreaBase * Number(preset.wall_exposure_factor || 1);

  // ======================
  // المواد القديمة (كما هي)
  // ======================
  
  // 1) Concrete
  {
    const mat = findMatByName("Concrete");
    const variant = chooseVariant(mat);
    const q = area * floors * Number(preset.concrete_m3_per_m2 || 0.12) * waste;
    if (mat && variant) items.push(buildItem(mat.name, mat.unit || "m3", q, variant.pricePerUnit, { materialId: String(mat._id), variantKey: variant.key, calc: { base: "area*floors*concrete_factor" } }));
  }

  // 2) Steel Rebar
  {
    const mat = findMatByName("Steel") || findMatByName("Rebar");
    const variant = chooseVariant(mat);
    const kg = area * floors * Number(preset.rebar_kg_per_m2 || 55) * waste;
    if (mat && variant) items.push(buildItem(mat.name, "ton", kg / 1000, variant.pricePerUnit, { materialId: String(mat._id), variantKey: variant.key, calc: { base: "area*floors*rebar_kg/1000" } }));
  }

  // 3) Blocks (Checking for "Block" or "Hollow")
  {
    const mat = findMatByName("Block") || findMatByName("Hollow");
    const variant = chooseVariant(mat);
    const qtyPerM2 = Number(variant?.quantityPerM2 || 12.5);
    const q = wallArea * qtyPerM2 * waste;
    if (mat && variant) items.push(buildItem(mat.name, mat.unit || "Piece", q, variant.pricePerUnit, { materialId: String(mat._id), variantKey: variant.key, calc: { base: "wallArea*qtyPerM2" } }));
  }

  // 4) Plaster
  {
    const mat = findMatByName("Plaster");
    const variant = chooseVariant(mat);
    const plasterWall = wallArea * Number(preset.plaster_wall_factor || 1.0);
    const qtyPerM2 = Number(variant?.quantityPerM2 || 1.0);
    const q = plasterWall * qtyPerM2 * waste;
    if (mat && variant) items.push(buildItem(mat.name, mat.unit || "m2", q, variant.pricePerUnit, { materialId: String(mat._id), variantKey: variant.key, calc: { base: "wallArea*plasterFactor" } }));
  }

  // 5) Paint
  {
    const mat = findMatByName("Paint"); 
    const variant = chooseVariant(mat);
    const ceilingArea = area * floors;
    const paintArea = (wallArea + ceilingArea) * coats * Number(preset.paint_factor || 0.85);
    const qtyPerM2 = Number(variant?.quantityPerM2 || 1.0); // usually coverage
    const q = paintArea * qtyPerM2 * waste;
    if (mat && variant) items.push(buildItem(mat.name, mat.unit || "Gallon", q, variant.pricePerUnit, { materialId: String(mat._id), variantKey: variant.key, calc: { base: "totalSurface*coats*coverage" } }));
  }

  // 6) Tiles
  {
    const mat = findMatByName("Tile") || findMatByName("Porcelain");
    const variant = chooseVariant(mat);
    const cover = Number(preset.tiles_floor_coverage || 0.8);
    const tilesArea = area * floors * cover * 1.05; // Skirting
    const q = tilesArea * (variant?.quantityPerM2 || 1) * waste;
    if (mat && variant) items.push(buildItem(mat.name, mat.unit || "m2", q, variant.pricePerUnit, { materialId: String(mat._id), variantKey: variant.key, calc: { base: "floorArea*coverage" } }));
  }

  // ======================
  // ✅ المواد الجديدة (New Additions)
  // ======================

  // 7) Sand (رمل)
  {
    const mat = findMatByName("Sand");
    const variant = chooseVariant(mat);
    if (mat && variant) {
      // الرمل يحسب تقديراً بناء على المساحة الكلية (شامل البناء والتشطيب)
      const q = area * floors * (variant.quantityPerM2 || 0.05) * waste;
      items.push(buildItem(mat.name, mat.unit, q, variant.pricePerUnit, {
        materialId: String(mat._id), variantKey: variant.key, calc: { base: "area*floors*qtyPerM2" }
      }));
    }
  }

  // 8) Aggregates (حصمة)
  {
    const mat = findMatByName("Aggregates") || findMatByName("Foul");
    const variant = chooseVariant(mat);
    if (mat && variant) {
      const q = area * floors * (variant.quantityPerM2 || 0.08) * waste;
      items.push(buildItem(mat.name, mat.unit, q, variant.pricePerUnit, {
        materialId: String(mat._id), variantKey: variant.key, calc: { base: "area*floors*qtyPerM2" }
      }));
    }
  }

  // 9) Aluminum Windows (شبابيك)
  {
    const mat = findMatByName("Aluminum") || findMatByName("Window");
    const variant = chooseVariant(mat);
    if (mat && variant) {
      // تقدير الشبابيك: عادة 15% من مساحة الأرضية
      const windowRatio = 0.15; 
      // أو نستخدم quantityPerM2 من الداتا بيس إذا كانت مضبوطة
      const factor = variant.quantityPerM2 > 0 ? variant.quantityPerM2 : windowRatio;
      const q = area * floors * factor; 
      
      items.push(buildItem(mat.name, mat.unit || "m2", q, variant.pricePerUnit, {
        materialId: String(mat._id), variantKey: variant.key, calc: { base: "area*floors*windowFactor" }
      }));
    }
  }

  // 10) Roller Shutters (أباجورات)
  {
    const mat = findMatByName("Shutter") || findMatByName("Roller");
    const variant = chooseVariant(mat);
    if (mat && variant) {
      // الأباجورات نفس مساحة الشبابيك تقريباً
      const factor = variant.quantityPerM2 > 0 ? variant.quantityPerM2 : 0.15;
      const q = area * floors * factor;
      items.push(buildItem(mat.name, mat.unit || "m2", q, variant.pricePerUnit, {
        materialId: String(mat._id), variantKey: variant.key, calc: { base: "same as windows" }
      }));
    }
  }

  // 11) Internal Doors (أبواب داخلية)
  {
    const mat = findMatByName("Internal Door");
    const variant = chooseVariant(mat);
    if (mat && variant) {
      // تقدير: باب لكل 30-35 متر مربع
      const factor = variant.quantityPerM2 > 0 ? variant.quantityPerM2 : (1/30);
      const rawQ = area * floors * factor;
      const q = Math.ceil(rawQ); // تقريب للأعلى (عدد صحيح)
      
      items.push(buildItem(mat.name, "Piece", q, variant.pricePerUnit, {
        materialId: String(mat._id), variantKey: variant.key, calc: { base: "ceil(area*floors / 30)" }
      }));
    }
  }

  // 12) Main Security Door (باب أمان)
  {
    const mat = findMatByName("Main Security") || findMatByName("Main Door");
    const variant = chooseVariant(mat);
    if (mat && variant) {
      // إذا فيلا: باب واحد. إذا شقق: باب لكل طابق (افتراضاً شقة بالطابق)
      let q = 1;
      if (buildingType === "apartment" || buildingType === "commercial") {
          q = floors; 
      }
      
      items.push(buildItem(mat.name, "Piece", q, variant.pricePerUnit, {
        materialId: String(mat._id), variantKey: variant.key, calc: { base: "1 per unit/floor" }
      }));
    }
  }

  // 13) Sanitary Ware (أطقم حمامات)
  {
    const mat = findMatByName("Sanitary") || findMatByName("Toilet");
    const variant = chooseVariant(mat);
    if (mat && variant) {
      // تقدير: حمام لكل 80 متر مربع
      const factor = variant.quantityPerM2 > 0 ? variant.quantityPerM2 : (1/80);
      const q = Math.ceil(area * floors * factor);
      items.push(buildItem(mat.name, "Set", q, variant.pricePerUnit, {
        materialId: String(mat._id), variantKey: variant.key, calc: { base: "ceil(area*floors / 80)" }
      }));
    }
  }

  // 14) Electrical Switches (كهرباء)
  {
    const mat = findMatByName("Switch") || findMatByName("Electrical");
    const variant = chooseVariant(mat);
    if (mat && variant) {
      // تقدير: نقطة لكل 2 متر مربع (أفياش + مفاتيح)
      const factor = variant.quantityPerM2 > 0 ? variant.quantityPerM2 : 0.5; 
      const q = Math.ceil(area * floors * factor);
      items.push(buildItem(mat.name, "Piece", q, variant.pricePerUnit, {
        materialId: String(mat._id), variantKey: variant.key, calc: { base: "area*floors*pointsFactor" }
      }));
    }
  }

    // 15) Water Tanks (خزانات)
  {
    const mat = findMatByName("Tank") || findMatByName("Water");
    const variant = chooseVariant(mat);
    if (mat && variant) {
      // خزان لكل وحدة سكنية (طابق)
      const q = (buildingType === "villa") ? 1 : floors;
      items.push(buildItem(mat.name, "Piece", q, variant.pricePerUnit, {
        materialId: String(mat._id), variantKey: variant.key, calc: { base: "1 per unit" }
      }));
    }
  }


  // ======================
  // Extras (Loop for anything else selected by user)
  // ======================
  // تم تحديث هذا اللوب ليتجاوز المواد التي تم حسابها بالأعلى تلقائياً
  const allCalculatedNames = [
    "Concrete", "Steel", "Rebar", "Block", "Hollow", "Plaster", "Paint", "Tile", "Porcelain",
    "Sand", "Aggregates", "Foul", "Aluminum", "Window", "Shutter", "Roller", 
    "Internal Door", "Main Security", "Main Door", "Sanitary", "Toilet", "Switch", "Electrical", "Tank", "Water"
  ];

  for (const s of selections) {
    const matId = String(s?.materialId || "");
    const variantKey = String(s?.variantKey || "");
    if (!matId || !variantKey) continue;

    const mat = byId.get(matId);
    if (!mat) continue;

    // تجاوز المواد المحسوبة سابقاً لتجنب التكرار
    const isAlreadyCalculated = allCalculatedNames.some(n => mat.name.includes(n));
    if (isAlreadyCalculated) continue;

    const variant = pickVariantByKey(mat, variantKey);
    if (!variant) continue;

    const qtyPerM2 = Number(variant.quantityPerM2 || 0);
    if (qtyPerM2 > 0) {
       const q = area * floors * qtyPerM2 * waste;
       items.push(
        buildItem(mat.name, mat.unit || "unit", q, variant.pricePerUnit, {
          materialId: String(mat._id),
          variantKey: variant.key,
          calc: { base: "area*floors*qtyPerM2 (extra)" },
        })
      );
    }
  }

  const totalCost = items.reduce((sum, it) => sum + (Number(it.total) || 0), 0);

  return {
    items,
    totalCost: Number(totalCost.toFixed(2)),
    currency: "JOD",
    finishingLevel: levelKey,
    buildingType,
    presetUsed: {
      ...preset,
      label: presetBase.label,
    },
  };
}

module.exports = {
  generateBoqForProject,
  approximatePerimeterFromArea,
  PRESETS,
};
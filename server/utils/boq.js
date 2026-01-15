// utils/boq.js
const Material = require("../models/Material");

// ======================
// Helpers
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
  // aliases
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
// Presets (Jordan-friendly rough coefficients)
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
// Main
// ======================
/**
 * generateBoqForProject(project, options)
 * options:
 *  - selections: [{ materialId, variantKey }]
 *  - buildingType: apartment/villa/commercial (اختياري)
 *  - overrides: لتعديل معاملات preset (اختياري)
 *
 * يعتمد على:
 *  - project.area (m2)
 *  - project.floors
 *  - project.finishingLevel
 *  - project.buildingType (لو موجود)
 */
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

  // selections mapping: materialId -> variantKey
  const selections = Array.isArray(options.selections) ? options.selections : [];
  const selectedById = new Map(
    selections
      .filter((s) => s && s.materialId && s.variantKey)
      .map((s) => [String(s.materialId), String(s.variantKey)])
  );

  // ✅ المواد الأساسية اللي إلها معادلات خاصة
  const neededNames = [
    "Concrete",
    "Steel Rebar",
    "Blocks",
    "Plaster",
    "Paint",
    "Tiles",
  ];

  // ✅ اجمع IDs اللي المستخدم اختارها (عشان نضيف extras تلقائيًا)
  const selectedIds = [
    ...new Set(
      selections
        .map((s) => (s && s.materialId ? String(s.materialId) : ""))
        .filter(Boolean)
    ),
  ];

  // ✅ هات المواد الأساسية + المواد المختارة دفعة واحدة
  const mats = await Material.find({
    $or: [{ name: { $in: neededNames } }, { _id: { $in: selectedIds } }],
  }).lean();

  const byName = new Map(mats.map((m) => [m.name, m]));
  const byId = new Map(mats.map((m) => [String(m._id), m]));

  function chooseVariant(mat) {
    if (!mat) return null;
    const chosenKey = selectedById.get(String(mat._id));
    if (chosenKey) return pickVariantByKey(mat, chosenKey);
    return pickVariantByLevel(mat, levelKey);
  }

  const items = [];

  // هندسة تقريبية
  const perimeter = approximatePerimeterFromArea(area);
  const wallAreaBase = perimeter * height * floors;
  const wallArea = wallAreaBase * Number(preset.wall_exposure_factor || 1);

  // ======================
  // 1) Concrete (m3)
  // ======================
  {
    const mat = byName.get("Concrete");
    const variant = chooseVariant(mat);
    const q = area * floors * Number(preset.concrete_m3_per_m2 || 0.12) * waste;

    if (mat && variant) {
      items.push(
        buildItem("Concrete", mat.unit || "m3", q, variant.pricePerUnit, {
          materialId: String(mat._id),
          variantKey: variant.key,
          calc: { base: "area*floors*concrete_m3_per_m2*waste" },
        })
      );
    }
  }

  // ======================
  // 2) Steel Rebar (ton)
  // ======================
  {
    const mat = byName.get("Steel Rebar");
    const variant = chooseVariant(mat);

    const kg = area * floors * Number(preset.rebar_kg_per_m2 || 55) * waste;
    const ton = kg / 1000;

    if (mat && variant) {
      items.push(
        buildItem("Steel Rebar", "ton", ton, variant.pricePerUnit, {
          materialId: String(mat._id),
          variantKey: variant.key,
          calc: { base: "area*floors*rebar_kg_per_m2*waste /1000" },
        })
      );
    }
  }

  // ======================
  // 3) Blocks (count)
  // ======================
  {
    const mat = byName.get("Blocks");
    const variant = chooseVariant(mat);

    const qtyPerM2 = Number(variant?.quantityPerM2 || 12);
    const q = wallArea * qtyPerM2 * waste;

    if (mat && variant) {
      items.push(
        buildItem("Blocks", mat.unit || "block", q, variant.pricePerUnit, {
          materialId: String(mat._id),
          variantKey: variant.key,
          calc: { base: "wallArea*qtyPerM2*waste" },
        })
      );
    }
  }

  // ======================
  // 4) Plaster (m2)
  // ======================
  {
    const mat = byName.get("Plaster");
    const variant = chooseVariant(mat);

    const plasterWall = wallArea * Number(preset.plaster_wall_factor || 1.0);
    const qtyPerM2 = Number(variant?.quantityPerM2 || 1.0);
    const q = plasterWall * qtyPerM2 * waste;

    if (mat && variant) {
      items.push(
        buildItem("Plaster", mat.unit || "m2", q, variant.pricePerUnit, {
          materialId: String(mat._id),
          variantKey: variant.key,
          calc: { base: "wallArea*plaster_wall_factor*qtyPerM2*waste" },
        })
      );
    }
  }

  // ======================
  // 5) Paint
  // ======================
  {
    const mat = byName.get("Paint");
    const variant = chooseVariant(mat);

    const ceilingArea = area * floors;
    const paintArea =
      (wallArea + ceilingArea) * coats * Number(preset.paint_factor || 0.85);

    const qtyPerM2 = Number(variant?.quantityPerM2 || 1.0);
    const q = paintArea * qtyPerM2 * waste;

    if (mat && variant) {
      items.push(
        buildItem("Paint", mat.unit || "m2", q, variant.pricePerUnit, {
          materialId: String(mat._id),
          variantKey: variant.key,
          calc: {
            base: "(wallArea+ceilingArea)*coats*paint_factor*qtyPerM2*waste",
          },
        })
      );
    }
  }

  // ======================
  // 6) Tiles (m2)
  // ======================
  {
    const mat = byName.get("Tiles");
    const variant = chooseVariant(mat);

    const cover = Number(preset.tiles_floor_coverage || 0.8);
    const tilesArea = area * floors * cover * 1.05;
    const qtyPerM2 = Number(variant?.quantityPerM2 || 1.0);
    const q = tilesArea * qtyPerM2 * waste;

    if (mat && variant) {
      items.push(
        buildItem("Tiles", mat.unit || "m2", q, variant.pricePerUnit, {
          materialId: String(mat._id),
          variantKey: variant.key,
          calc: { base: "area*floors*tiles_floor_coverage*1.05*qtyPerM2*waste" },
        })
      );
    }
  }

  // ======================
  // ✅ Extras: أي مادة اختارها المستخدم تنضاف تلقائيًا (إذا إلها quantityPerM2)
  // ======================
  for (const s of selections) {
    const matId = String(s?.materialId || "");
    const variantKey = String(s?.variantKey || "");
    if (!matId || !variantKey) continue;

    const mat = byId.get(matId);
    if (!mat) continue;

    // لا تعيد إضافة المواد الأساسية (لأن انحسبت فوق)
    if (neededNames.includes(mat.name)) continue;

    const variant = pickVariantByKey(mat, variantKey);
    if (!variant) continue;

    const qtyPerM2 = Number(variant.quantityPerM2 || 0);
    if (!(qtyPerM2 > 0)) {
      // إذا ما عندها كمية/م2، بنتركها (بدك إلها معادلة خاصة لاحقًا)
      continue;
    }

    const q = area * floors * qtyPerM2 * waste;

    items.push(
      buildItem(mat.name, mat.unit || "unit", q, variant.pricePerUnit, {
        materialId: String(mat._id),
        variantKey: variant.key,
        calc: { base: "area*floors*qtyPerM2*waste (extra selected)" },
      })
    );
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

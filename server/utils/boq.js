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

/**
 * Normalize buildingType to:
 * "House" | "Villa" | "Commercial"
 */
function normalizeBuildingType(t) {
  const v = String(t || "").trim().toLowerCase();

  if (v === "house") return "House";
  if (v === "villa") return "Villa";
  if (v === "commercial") return "Commercial";

  // aliases
  if (["apartment", "flat"].includes(v)) return "House";
  if (["shop", "office", "store"].includes(v)) return "Commercial";

  // default
  return "House";
}

function pickVariantByKey(materialDoc, variantKey) {
  if (!materialDoc || !variantKey) return null;
  const vars = Array.isArray(materialDoc.variants) ? materialDoc.variants : [];
  return vars.find((x) => String(x.key) === String(variantKey)) || null;
}

function buildItem(
  name,
  unit,
  quantity,
  pricePerUnit,
  meta = {},
  variantLabel = ""
) {
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
// Presets (Apartment -> House)
// ======================
const PRESETS = {
  House: {
    label: "House",
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

  Villa: {
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

  Commercial: {
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

  const buildingType = normalizeBuildingType(
    options.buildingType || project.buildingType || "House"
  );

  // ✅ preset مطابق تمامًا للمودل
  const presetBase = PRESETS[buildingType] || PRESETS.House;
  const overrides = options.overrides || {};
  const preset = { ...presetBase, ...overrides };

  const height = Number(preset.height);
  const coats = Number(preset.coats);
  const waste = Number(preset.waste);

  // ======================
  // Selections
  // ======================
  const selections = Array.isArray(options.selections) ? options.selections : [];

  if (selections.length === 0) {
    return {
      items: [],
      totalCost: 0,
      currency: "JOD",
      buildingType,
      error: "Please choose at least one material",
    };
  }

  const selectedById = new Map(
    selections
      .filter((s) => s?.materialId && s?.variantKey)
      .map((s) => [String(s.materialId), String(s.variantKey)])
  );

  const mats = await Material.find({
    _id: { $in: [...selectedById.keys()] },
  }).lean();

  function getVariantInfo(mat) {
    const key = selectedById.get(String(mat._id));
    if (!key) return null;

    const v = pickVariantByKey(mat, key);
    if (!v) return null;

    return {
      ...v,
      displayLabel: v.label || v.key || "Standard",
    };
  }

  const findMatByName = (name) =>
    mats.find((m) =>
      String(m.name).toLowerCase().includes(name.toLowerCase())
    );

  const items = [];

  const perimeter = approximatePerimeterFromArea(area);
  const wallArea =
    perimeter * height * floors * preset.wall_exposure_factor;

  // ======================
  // Concrete
  // ======================
  {
    const mat = findMatByName("Concrete");
    const v = getVariantInfo(mat);
    if (mat && v) {
      const q = area * floors * preset.concrete_m3_per_m2 * waste;
      items.push(
        buildItem(
          mat.name,
          mat.unit,
          q,
          v.pricePerUnit,
          { materialId: mat._id, variantKey: v.key },
          v.displayLabel
        )
      );
    }
  }

  // ======================
  // Steel
  // ======================
  {
    const mat = findMatByName("Steel") || findMatByName("Rebar");
    const v = getVariantInfo(mat);
    if (mat && v) {
      const kg = area * floors * preset.rebar_kg_per_m2 * waste;
      items.push(
        buildItem(
          mat.name,
          "ton",
          kg / 1000,
          v.pricePerUnit,
          { materialId: mat._id, variantKey: v.key },
          v.displayLabel
        )
      );
    }
  }

  // ======================
  // Blocks
  // ======================
  {
    const mat = findMatByName("Block");
    const v = getVariantInfo(mat);
    if (mat && v) {
      const q = wallArea * (v.quantityPerM2 || 12.5) * waste;
      items.push(
        buildItem(
          mat.name,
          mat.unit || "Piece",
          q,
          v.pricePerUnit,
          { materialId: mat._id, variantKey: v.key },
          v.displayLabel
        )
      );
    }
  }

  // ======================
  // Paint
  // ======================
  {
    const mat = findMatByName("Paint");
    const v = getVariantInfo(mat);
    if (mat && v) {
      const paintArea =
        (wallArea + area * floors) * coats * preset.paint_factor;
      const q = paintArea * (v.quantityPerM2 || 1) * waste;

      items.push(
        buildItem(
          mat.name,
          mat.unit || "Gallon",
          q,
          v.pricePerUnit,
          { materialId: mat._id, variantKey: v.key },
          v.displayLabel
        )
      );
    }
  }

  // ======================
  // Tiles
  // ======================
  {
    const mat = findMatByName("Tile");
    const v = getVariantInfo(mat);
    if (mat && v) {
      const q =
        area *
        floors *
        preset.tiles_floor_coverage *
        (v.quantityPerM2 || 1) *
        waste;

      items.push(
        buildItem(
          mat.name,
          mat.unit || "m2",
          q,
          v.pricePerUnit,
          { materialId: mat._id, variantKey: v.key },
          v.displayLabel
        )
      );
    }
  }

  const totalCost = items.reduce((s, i) => s + i.total, 0);

  return {
    items,
    totalCost: Number(totalCost.toFixed(2)),
    currency: "JOD",
    buildingType, // House | Villa | Commercial
  };
}

module.exports = { generateBoqForProject, PRESETS };

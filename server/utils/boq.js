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

// Updated: Accepts variantLabel to return it to frontend
function buildItem(name, unit, quantity, pricePerUnit, meta = {}, variantLabel = "") {
  const q = Number(quantity || 0);
  const p = Number(pricePerUnit || 0);
  return {
    name,
    quantity: Number(q.toFixed(2)),
    unit,
    pricePerUnit: p,
    total: Number((q * p).toFixed(2)),
    variantLabel: variantLabel, // <--- Sent to Frontend
    ...meta,
  };
}

// ======================
// Presets (Unchanged)
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
  
  const buildingType = normalizeBuildingType(
    options.buildingType || project.buildingType || "apartment"
  );

  const presetBase = PRESETS[buildingType] || PRESETS.apartment;
  const overrides = options.overrides || {};
  const preset = { ...presetBase, ...overrides };

  const height = Number(preset.height || 3);
  const coats = Number(preset.coats || 2);
  const waste = Number(preset.waste || 1.05);

  // 1. Get Selections
  const selections = Array.isArray(options.selections) ? options.selections : [];
  
  if (selections.length === 0) {
     return { 
       items: [], 
       totalCost: 0, 
       currency: "JOD", 
       error: "Please choose at least one material"
     };
  }

  // Map: MaterialID -> VariantKey
  const selectedById = new Map(
    selections
      .filter((s) => s && s.materialId && s.variantKey)
      .map((s) => [String(s.materialId), String(s.variantKey)])
  );

  // Fetch only selected materials
  const selectedIds = Array.from(selectedById.keys());
  const mats = await Material.find({ _id: { $in: selectedIds } }).lean();

  // Helper to pick variant and get label
  function getVariantInfo(mat) {
    if (!mat) return null;
    const chosenKey = selectedById.get(String(mat._id));
    if (!chosenKey) return null;
    
    const v = pickVariantByKey(mat, chosenKey);
    if (!v) return null;

    return { 
        ...v, 
        // Ensure we have a label for display
        displayLabel: v.label || v.key || "Standard" 
    };
  }

  // Find inside *fetched* materials (which are only the selected ones)
  const findMatByName = (partialName) => {
    return mats.find(m => m.name.toLowerCase().includes(partialName.toLowerCase()));
  };

  const items = [];
  const perimeter = approximatePerimeterFromArea(area);
  const wallAreaBase = perimeter * height * floors;
  const wallArea = wallAreaBase * Number(preset.wall_exposure_factor || 1);

  // ====================================================
  // Calculations
  // ====================================================

  // 1. Concrete
  {
    const mat = findMatByName("Concrete");
    const variant = getVariantInfo(mat);
    if (mat && variant) {
      const q = area * floors * Number(preset.concrete_m3_per_m2 || 0.12) * waste;
      items.push(buildItem(mat.name, mat.unit, q, variant.pricePerUnit, 
        { materialId: String(mat._id), variantKey: variant.key }, variant.displayLabel));
    }
  }

  // 2. Steel Rebar
  {
    const mat = findMatByName("Steel") || findMatByName("Rebar");
    const variant = getVariantInfo(mat);
    if (mat && variant) {
      const kg = area * floors * Number(preset.rebar_kg_per_m2 || 55) * waste;
      items.push(buildItem(mat.name, "ton", kg / 1000, variant.pricePerUnit, 
        { materialId: String(mat._id), variantKey: variant.key }, variant.displayLabel));
    }
  }

  // 3. Blocks
  {
    const mat = findMatByName("Block") || findMatByName("Hollow");
    const variant = getVariantInfo(mat);
    if (mat && variant) {
      const qtyPerM2 = Number(variant.quantityPerM2 || 12.5);
      const q = wallArea * qtyPerM2 * waste;
      items.push(buildItem(mat.name, mat.unit || "Piece", q, variant.pricePerUnit, 
        { materialId: String(mat._id), variantKey: variant.key }, variant.displayLabel));
    }
  }

  // 4. Paint
  {
    const mat = findMatByName("Paint");
    const variant = getVariantInfo(mat);
    if (mat && variant) {
      const ceilingArea = area * floors;
      const paintArea = (wallArea + ceilingArea) * coats * Number(preset.paint_factor || 0.85);
      const qty = variant.quantityPerM2 || 1.0; 
      const q = paintArea * qty * waste;
      items.push(buildItem(mat.name, mat.unit || "Gallon", q, variant.pricePerUnit, 
        { materialId: String(mat._id), variantKey: variant.key }, variant.displayLabel));
    }
  }

  // 5. Tiles
  {
    const mat = findMatByName("Tile") || findMatByName("Porcelain");
    const variant = getVariantInfo(mat);
    if (mat && variant) {
      const cover = Number(preset.tiles_floor_coverage || 0.8);
      const tilesArea = area * floors * cover * 1.05;
      const q = tilesArea * (variant.quantityPerM2 || 1) * waste;
      items.push(buildItem(mat.name, mat.unit || "m2", q, variant.pricePerUnit, 
        { materialId: String(mat._id), variantKey: variant.key }, variant.displayLabel));
    }
  }

  // 6. Generic Calculation (Rest of selected materials)
  const calculatedIds = items.map(i => i.materialId);
  
  for (const m of mats) {
    if (calculatedIds.includes(String(m._id))) continue; 

    const variant = getVariantInfo(m);
    if (!variant) continue;

    const qtyPerM2 = Number(variant.quantityPerM2 || 0);
    
    // Logic 1: Per m2
    if (qtyPerM2 > 0) {
       const q = area * floors * qtyPerM2 * waste;
       items.push(buildItem(m.name, m.unit, q, variant.pricePerUnit, 
        { materialId: String(m._id), variantKey: variant.key }, variant.displayLabel));
    } 
    // Logic 2: Per Piece/Set
    else if (["piece", "set", "unit", "door"].includes(m.unit.toLowerCase())) {
        const defaultFactor = 1/50; 
        const q = Math.ceil(area * floors * defaultFactor);
        items.push(buildItem(m.name, m.unit, q, variant.pricePerUnit, 
            { materialId: String(m._id), variantKey: variant.key }, variant.displayLabel));
    }
    // Logic 3: Fallback (Just 1 unit just in case)
    else {
        items.push(buildItem(m.name, m.unit, 1, variant.pricePerUnit, 
            { materialId: String(m._id), variantKey: variant.key }, variant.displayLabel));
    }
  }

  const totalCost = items.reduce((sum, it) => sum + (Number(it.total) || 0), 0);

  return {
    items,
    totalCost: Number(totalCost.toFixed(2)),
    currency: "JOD",
    buildingType,
  };
}

module.exports = { generateBoqForProject, PRESETS };
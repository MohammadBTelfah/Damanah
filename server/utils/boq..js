// utils/boq.js
const Material = require("../models/Material");

// تقريب محيط المبنى من المساحة (نفترضه شبه مربع)
function approximatePerimeterFromArea(area) {
  if (!area || area <= 0) return 0;
  const side = Math.sqrt(area);
  return 4 * side;
}

/**
 * تحويل finishingLevel بالمشروع إلى key موجود عندك بالـ variants:
 * basic / medium / premium
 */
function normalizeLevel(level) {
  const v = String(level || "").toLowerCase().trim();

  // دعم أسماء مختلفة من مشروعك
  if (v === "basic") return "basic";
  if (v === "medium") return "medium";
  if (v === "premium") return "premium";

  if (v === "standard") return "medium";
  if (v === "luxury") return "premium";

  // افتراضي
  return "medium";
}

function pickVariant(materialDoc, levelKey) {
  if (!materialDoc) return null;
  const vars = Array.isArray(materialDoc.variants) ? materialDoc.variants : [];
  const exact = vars.find((x) => x.key === levelKey);
  return exact || vars[0] || null;
}

/**
 * يبني BOQ item من مادة واحدة
 * quantity: كمية محسوبة
 */
function buildItem(materialName, unit, quantity, pricePerUnit) {
  const q = Number(quantity || 0);
  const p = Number(pricePerUnit || 0);
  return {
    name: materialName,
    quantity: Number(q.toFixed(2)),
    unit,
    pricePerUnit: p,
    total: Number((q * p).toFixed(2)),
  };
}

/**
 * ✅ generate BOQ من مواد الداتا بيس
 * يعتمد على:
 * - project.area
 * - project.floors
 * - project.finishingLevel
 */
async function generateBoqForProject(project, options = {}) {
  const area = Number(project.area || 0);
  const floors = Number(project.floors || 1);
  const height = Number(options.height || 3);
  const coats = Number(options.coats || 2);

  const levelKey = normalizeLevel(project.finishingLevel);

  // أسماء المواد لازم تطابق اللي أدخلتها بالـ DB بالضبط
  const neededNames = [
    "Concrete",
    "Steel Rebar",
    "Blocks",
    "Plaster",
    "Paint",
    "Tiles",
  ];

  const materials = await Material.find({ name: { $in: neededNames } }).lean();
  const map = new Map(materials.map((m) => [m.name, m]));

  const items = [];

  // 1) Concrete: كمية تقريبية = area * floors * 0.12 (مثل كودك)
  {
    const mat = map.get("Concrete");
    const variant = pickVariant(mat, levelKey);

    const concretePerM2 = 0.12;
    const quantity = area * floors * concretePerM2;

    if (variant) {
      items.push(buildItem("Concrete", mat.unit, quantity, variant.pricePerUnit));
    }
  }

  // 2) Steel Rebar: area * floors * 0.07 (مثل كودك)
  {
    const mat = map.get("Steel Rebar");
    const variant = pickVariant(mat, levelKey);

    const steelPerM2 = 0.07;
    const quantity = area * floors * steelPerM2;

    if (variant) {
      items.push(buildItem("Steel Rebar", mat.unit, quantity, variant.pricePerUnit));
    }
  }

  // 3) Blocks: نحسب wallArea ثم نستخدم quantityPerM2 من الـ variant
  {
    const mat = map.get("Blocks");
    const variant = pickVariant(mat, levelKey);

    const perimeter = approximatePerimeterFromArea(area);
    const wallArea = perimeter * height;

    // استهلاك بلوك لكل m2 من الحيط (انت حاطه بالـ DB)
    const qtyPerM2 = Number(variant?.quantityPerM2 || 0);
    const blocksCount = wallArea * qtyPerM2;

    if (variant) {
      items.push(buildItem("Blocks", mat.unit, blocksCount, variant.pricePerUnit));
    }
  }

  // 4) Plaster: wallArea * 1.05 ثم quantityPerM2 (عادة 1.0~1.1)
  {
    const mat = map.get("Plaster");
    const variant = pickVariant(mat, levelKey);

    const perimeter = approximatePerimeterFromArea(area);
    const wallArea = perimeter * height;
    const plasterArea = wallArea * 1.05;

    const qtyPerM2 = Number(variant?.quantityPerM2 || 1);
    const quantity = plasterArea * qtyPerM2;

    if (variant) {
      items.push(buildItem("Plaster", mat.unit, quantity, variant.pricePerUnit));
    }
  }

  // 5) Paint: (wallArea + ceilingArea) * coats ثم quantityPerM2 (انت حاطها 3.0..)
  {
    const mat = map.get("Paint");
    const variant = pickVariant(mat, levelKey);

    const perimeter = approximatePerimeterFromArea(area);
    const wallArea = perimeter * height;
    const ceilingArea = area;

    const totalPaintArea = (wallArea + ceilingArea) * coats;

    // quantityPerM2 عندك تمثل "استهلاك" (مثلاً 3.0)
    const qtyPerM2 = Number(variant?.quantityPerM2 || 1);
    const quantity = totalPaintArea * qtyPerM2;

    if (variant) {
      items.push(buildItem("Paint", mat.unit, quantity, variant.pricePerUnit));
    }
  }

  // 6) Tiles: area * 1.1 ثم quantityPerM2 (عندك 1.1)
  {
    const mat = map.get("Tiles");
    const variant = pickVariant(mat, levelKey);

    const tilesArea = area * 1.1;
    const qtyPerM2 = Number(variant?.quantityPerM2 || 1);
    const quantity = tilesArea * qtyPerM2;

    if (variant) {
      items.push(buildItem("Tiles", mat.unit, quantity, variant.pricePerUnit));
    }
  }

  const totalCost = items.reduce((sum, item) => sum + (item.total || 0), 0);

  return {
    items,
    totalCost: Number(totalCost.toFixed(2)),
    currency: "JOD",
    finishingLevel: levelKey,
  };
}

module.exports = {
  generateBoqForProject,
  approximatePerimeterFromArea,
};

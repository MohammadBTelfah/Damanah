// utils/boq.js

// تقريب محيط المبنى من المساحة (نفترضه شبه مربع)
function approximatePerimeterFromArea(area) {
  if (!area || area <= 0) return 0;
  const side = Math.sqrt(area);
  return 4 * side;
}

// 🔹 حديد التسليح
function estimateSteel(area, floors) {
  const steelPerM2 = 0.07; // طن لكل متر مربع لكل طابق (قيمة تقريبية)
  const quantity = area * floors * steelPerM2;
  const pricePerTon = 650; // دينار للطن (عدّل حسب الأسعار المحلية)

  return {
    name: "steel",
    quantity: Number(quantity.toFixed(2)),
    unit: "ton",
    pricePerUnit: pricePerTon,
    total: Number((quantity * pricePerTon).toFixed(2)),
  };
}

// 🔹 الخرسانة (باطون) تقريباً
function estimateConcrete(area, floors) {
  const concretePerM2 = 0.12; // م3 لكل م2 (أساسات + سلابات تقريباً)
  const quantity = area * floors * concretePerM2;
  const pricePerM3 = 75; // دينار للمتر المكعب

  return {
    name: "concrete",
    quantity: Number(quantity.toFixed(2)),
    unit: "m3",
    pricePerUnit: pricePerM3,
    total: Number((quantity * pricePerM3).toFixed(2)),
  };
}

// 🔹 الطوب / البلوك
function estimateBlocks(area, height = 3) {
  const perimeter = approximatePerimeterFromArea(area);
  const wallArea = perimeter * height;

  const blockFaceArea = 0.08; // م2 (بلوك 40x20 تقريبا)
  const blocksCount = wallArea / blockFaceArea;

  const pricePerBlock = 0.45; // دينار للبلوك الواحد

  return {
    name: "blocks",
    quantity: Number(blocksCount.toFixed(0)),
    unit: "block",
    pricePerUnit: pricePerBlock,
    total: Number((blocksCount * pricePerBlock).toFixed(2)),
  };
}

// 🔹 القصارة (محارة)
function estimatePlaster(area, height = 3) {
  const perimeter = approximatePerimeterFromArea(area);
  const wallArea = perimeter * height;

  const plasterArea = wallArea * 1.05; // +5% هالك
  const pricePerM2 = 3.0; // دينار للمتر المربع

  return {
    name: "plaster",
    quantity: Number(plasterArea.toFixed(2)),
    unit: "m2",
    pricePerUnit: pricePerM2,
    total: Number((plasterArea * pricePerM2).toFixed(2)),
  };
}

// 🔹 الدهان (جدران + سقف)
function estimatePaint(area, height = 3, coats = 2) {
  const perimeter = approximatePerimeterFromArea(area);
  const wallArea = perimeter * height;
  const ceilingArea = area;

  const totalPaintArea = (wallArea + ceilingArea) * coats;
  const pricePerM2 = 2.5; // دينار/م2 لطبقتين تقريباً

  return {
    name: "paint",
    quantity: Number(totalPaintArea.toFixed(2)),
    unit: "m2",
    pricePerUnit: pricePerM2,
    total: Number((totalPaintArea * pricePerM2).toFixed(2)),
  };
}

// 🔹 البلاط (أرضيات)
function estimateTiles(area) {
  const tilesArea = area * 1.1; // +10% هالك
  const pricePerM2 = 6.0; // دينار/م2

  return {
    name: "tiles",
    quantity: Number(tilesArea.toFixed(2)),
    unit: "m2",
    pricePerUnit: pricePerM2,
    total: Number((tilesArea * pricePerM2).toFixed(2)),
  };
}


// 🔹 توليد BOQ كامل لمشروع واحد
function generateBoqForProject(project) {
  const area = project.area || 0;
  const floors = project.floors || 1;

  const items = [];

  items.push(estimateConcrete(area, floors));
  items.push(estimateSteel(area, floors));
  items.push(estimateBlocks(area));
  items.push(estimatePlaster(area));
  items.push(estimatePaint(area));
  items.push(estimateTiles(area));

  const totalCost = items.reduce((sum, item) => sum + item.total, 0);

  return {
    items,
    totalCost: Number(totalCost.toFixed(2)),
    currency: "JOD",
  };
}

module.exports = {
  generateBoqForProject,
  estimateSteel,
  estimateConcrete,
  estimateBlocks,
  estimatePlaster,
  estimatePaint,
  estimateTiles,
};

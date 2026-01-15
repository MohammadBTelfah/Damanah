// services/identity_ocr.service.js
// ✅ OCR helper (placeholder) — اربطه مع OCR provider لاحقاً
// يرجّع اقتراح للرقم الوطني + confidence + rawText

function normalizeText(text = "") {
  return String(text)
    .replace(/[^\S\r\n]+/g, " ") // collapse spaces
    .replace(/[٠-٩]/g, (d) => "٠١٢٣٤٥٦٧٨٩".indexOf(d)) // Arabic digits -> Latin
    .trim();
}

/**
 * ✅ استخراج رقم وطني أردني:
 * - 10 أرقام
 * - غالباً يبدأ بـ 2
 * - نفضّل اللي يجي قريب من كلمات: رقم وطني / National ID / ID No
 */
function extractJordanNationalId(text) {
  const t = normalizeText(text);
  if (!t) return null;

  // 1) سياق قوي: كلمات تدل على الرقم الوطني + بعدها الرقم
  const ctxRegex =
    /(national\s*id|id\s*no|id\s*number|رقم\s*وطني|الرقم\s*الوطني)[^\d]{0,20}(2\d{9})/i;

  const ctx = t.match(ctxRegex);
  if (ctx && ctx[2]) return ctx[2];

  // 2) أي رقم يبدأ بـ 2 وطوله 10
  const candidates = t.match(/\b2\d{9}\b/g) || [];
  if (candidates.length === 1) return candidates[0];

  // 3) fallback: أي 10 أرقام (بس آخر خيار)
  const any10 = t.match(/\b\d{10}\b/g) || [];

  // لو في أكثر من خيار، اختار الأكثر منطقية:
  // - فضّل اللي يبدأ بـ 2
  const all = [...candidates, ...any10].filter(Boolean);
  if (all.length === 0) return null;

  const prefer2 = all.find((x) => String(x).startsWith("2"));
  return prefer2 || all[0];
}

async function extractNationalIdFromIdentity(identityDocumentUrl) {
  // TODO: اربطه مع OCR الحقيقي:
  // - حمّل الصورة من identityDocumentUrl
  // - شغل OCR (google vision / tesseract / aws textract...)
  // - رجّع extractedText الحقيقي

  // ✅ placeholder نص للتجربة فقط
  const extractedText = "Name: ... National ID: 1234567890";

  const nationalId = extractJordanNationalId(extractedText);

  // confidence هنا placeholder — بالـOCR الحقيقي بتجيب confidence من المزود
  const confidence = nationalId ? 0.85 : null;

  return {
    nationalId,          // اقتراح
    confidence,          // رقم تقريبي
    rawText: extractedText,
    source: "placeholder",
    identityDocumentUrl,
  };
}

module.exports = {
  extractJordanNationalId,
  extractNationalIdFromIdentity,
};

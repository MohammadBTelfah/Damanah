// services/identity_ocr.service.js
// ✅ هذا ملف placeholder: اربطه مع OCR provider لاحقاً
// المفروض يرجّع { nationalId, confidence }

function extractJordanNationalId(text) {
  // ✅ استخراج رقم وطني أردني (غالباً 10 أرقام) — عدّل regex حسب تنسيق بلدك
  const match = text.match(/\b\d{10}\b/);
  return match ? match[0] : null;
}

async function extractNationalIdFromIdentity(identityDocumentUrl) {
  // TODO: هون تربط OCR الحقيقي:
  // - حمّل الصورة/PDF
  // - شغل OCR
  // - خذ النص المستخرج

  // مثال نص وهمي للتجربة:
  const extractedText = "Name: ... National ID: 1234567890";

  const nationalId = extractJordanNationalId(extractedText);

  return {
    nationalId,
    confidence: nationalId ? 0.85 : null,
    rawText: extractedText, // اختياري للتشخيص
  };
}

module.exports = {
  extractNationalIdFromIdentity,
};

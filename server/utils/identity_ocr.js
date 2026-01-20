const Tesseract = require("tesseract.js");

// دالة تنظيف النص (إزالة المسافات الزائدة وتحويل الأرقام العربية إلى إنجليزية)
function normalizeText(text = "") {
  return String(text)
    .replace(/[^\S\r\n]+/g, " ") // دمج المسافات
    .replace(/[٠-٩]/g, (d) => "٠١٢٣٤٥٦٧٨٩".indexOf(d)) // تحويل الأرقام للعربية
    .trim();
}

/**
 * محاولة استخراج الاسم (تجريبي)
 * تبحث عن كلمة "الاسم" وتأخذ ما بعدها
 */
function extractName(text) {
  const t = normalizeText(text);
  // يبحث عن: الاسم : فلان الفلاني
  // \s* تعني مسافات محتملة
  // ([:.-])? تعني قد يكون هناك نقطتين أو شرطة أو لا شيء
  const nameRegex = /(?:الاسم|name)\s*[:.-]?\s*([\u0600-\u06FF\s]+)/i;
  const match = t.match(nameRegex);
  
  if (match && match[1]) {
    // تنظيف النتيجة (نأخذ أول 4 كلمات مثلاً)
    return match[1].trim().split(/\s+/).slice(0, 4).join(" ");
  }
  return null;
}

/**
 * استخراج الرقم الوطني الأردني
 */
function extractJordanNationalId(text) {
  const t = normalizeText(text);
  if (!t) return null;

  // 1. البحث عن سياق (رقم وطني: xxxxx)
  const ctxRegex = /(?:national\s*id|no|num|رقم\s*وطني|الرقم)[^\d\n]{0,10}(\d{10})/i;
  const ctx = t.match(ctxRegex);
  if (ctx && ctx[1] && ctx[1].startsWith("2")) return ctx[1];

  // 2. البحث عن أي رقم يبدأ بـ 2 وطوله 10 خانات (الأكثر شيوعاً في الأردن)
  const candidates = t.match(/\b2\d{9}\b/g) || [];
  if (candidates.length > 0) return candidates[0];

  // 3. أي 10 أرقام
  const any10 = t.match(/\b\d{10}\b/g) || [];
  return any10.length > 0 ? any10[0] : null;
}

/**
 * الدالة الرئيسية: تأخذ رابط الصورة وتعيد البيانات
 */
async function extractNationalIdFromIdentity(identityDocumentUrl) {
  try {
    console.log("OCR Starting for:", identityDocumentUrl);

    // تشغيل Tesseract (يدعم العربية والإنجليزية)
    const { data: { text } } = await Tesseract.recognize(
      identityDocumentUrl,
      'ara+eng', // لغة عربية + إنجليزية
      { 
        //logger: m => console.log(m) // شيل التعليق لو بدك تشوف شريط التقدم
      }
    );

    const cleanText = normalizeText(text);
    
    // استخراج البيانات
    const nationalId = extractJordanNationalId(cleanText);
    const extractedName = extractName(cleanText);

    // حساب نسبة الثقة (بسيط)
    const confidence = nationalId ? (extractedName ? 0.9 : 0.7) : 0.0;

    return {
      nationalId,       // الرقم الوطني المستخرج
      extractedName,    // الاسم المستخرج (إن وجد)
      rawText: text,    // النص الخام (للمراجعة اليدوية)
      confidence,
      identityDocumentUrl // نعيد الرابط للحفظ
    };

  } catch (error) {
    console.error("OCR Error:", error);
    return {
      nationalId: null,
      extractedName: null,
      rawText: "",
      confidence: 0,
      error: error.message
    };
  }
}

module.exports = {
  extractNationalIdFromIdentity,
};
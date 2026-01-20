const Tesseract = require("tesseract.js");

// ===========================
// Helpers: Normalize
// ===========================

// تنظيف النص + تحويل أرقام عربية إلى إنجليزية
function normalizeText(text = "") {
  return String(text)
    .replace(/[^\S\r\n]+/g, " ") // دمج المسافات
    .replace(/[٠-٩]/g, (d) => "٠١٢٣٤٥٦٧٨٩".indexOf(d)) // تحويل الأرقام العربية إلى إنجليزية
    .trim();
}

// تنظيف الاسم الإنجليزي (إزالة رموز غير مطلوبة)
function cleanupEnglishName(s = "") {
  return String(s)
    .replace(/[^A-Za-z\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

// فلترة سريعة: هل السطر يبدو اسم إنجليزي (2-6 كلمات)
function isLikelyEnglishName(s = "") {
  const v = cleanupEnglishName(s);
  if (!v) return false;

  const parts = v.split(/\s+/).filter(Boolean);
  if (parts.length < 2 || parts.length > 6) return false;

  // استبعاد كلمات ليست أسماء (غالبًا تظهر على الهوية)
  const bad =
    /(hashemite|kingdom|jordan|id|card|national|sex|male|female|date|birth|place|expiry|issue|signature|serial|no|number|department|passport|civil)/i;

  if (bad.test(v)) return false;

  // يجب أن تكون معظم الكلمات أحرف
  const letters = (v.match(/[A-Za-z]/g) || []).length;
  return letters >= Math.min(6, v.length * 0.6);
}

/**
 * استخراج الاسم الإنجليزي من الهوية (مخصص للهوية الأردنية)
 * - يحاول يلقط Name: ...
 * - يتحمل أخطاء OCR مثل Narne / Nane
 * - fallback: يلقط أطول سطر "يشبه اسم" (Uppercase غالباً)
 */
function extractEnglishName(text) {
  const t = normalizeText(text);
  if (!t) return null;

  // 1) محاولة مباشرة: Name: XXXXX
  // بعض أخطاء OCR: Narne / Nane بدل Name
  const directRegex =
    /\bN(?:ame|arne|ane)\b\s*[:\-]?\s*([A-Z][A-Za-z\s]{6,80})/;

  const m1 = t.match(directRegex);
  if (m1 && m1[1]) {
    const cand = cleanupEnglishName(m1[1]);
    if (isLikelyEnglishName(cand)) return cand;
  }

  // 2) محاولة ثانية: أحياناً يطلع الاسم بسطر قريب من "Name" بدون نقطتين
  const nearNameRegex =
    /\bN(?:ame|arne|ane)\b\s+([A-Z][A-Za-z\s]{6,80})/;

  const m2 = t.match(nearNameRegex);
  if (m2 && m2[1]) {
    const cand = cleanupEnglishName(m2[1]);
    if (isLikelyEnglishName(cand)) return cand;
  }

  // 3) fallback: التقط أسطر، ودوّر على مرشحين
  const lines = t
    .split(/\r?\n/)
    .map((x) => x.trim())
    .filter(Boolean);

  const candidates = [];

  for (const line of lines) {
    // التقط أي مجموعة من 2-6 كلمات إنجليزية تبدأ بحرف كبير
    const mm = line.match(/\b([A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+){1,5})\b/);
    if (mm && mm[1]) {
      const cand = cleanupEnglishName(mm[1]);
      if (isLikelyEnglishName(cand)) candidates.push(cand);
    }

    // التقط أسطر uppercase بالكامل (غالباً الاسم يطلع uppercase)
    // مثال: MOHAMMAD BASAM MOHAMMAD TELFAH
    if (/^[A-Z]{2,}(?:\s+[A-Z]{2,}){1,5}$/.test(line)) {
      const cand = cleanupEnglishName(line);
      if (isLikelyEnglishName(cand)) candidates.push(cand);
    }
  }

  if (candidates.length === 0) return null;

  // رجّع الأطول (غالباً اسم كامل)
  candidates.sort((a, b) => b.length - a.length);
  return candidates[0];
}

/**
 * استخراج الرقم الوطني الأردني
 */
function extractJordanNationalId(text) {
  const t = normalizeText(text);
  if (!t) return null;

  // 1) سياق "National ID" أو "رقم وطني" ثم 10 أرقام
  const ctxRegex =
    /(?:national\s*id|no|num|رقم\s*وطني|الرقم)[^\d\n]{0,10}(\d{10})/i;
  const ctx = t.match(ctxRegex);
  if (ctx && ctx[1] && ctx[1].startsWith("2")) return ctx[1];

  // 2) أي رقم يبدأ بـ 2 وطوله 10 خانات (الأكثر شيوعاً بالأردن)
  const candidates = t.match(/\b2\d{9}\b/g) || [];
  if (candidates.length > 0) return candidates[0];

  // 3) أي 10 أرقام
  const any10 = t.match(/\b\d{10}\b/g) || [];
  return any10.length > 0 ? any10[0] : null;
}

/**
 * الدالة الرئيسية: تأخذ رابط/مسار الصورة وتعيد البيانات
 */
async function extractNationalIdFromIdentity(identityDocumentUrl) {
  try {
    console.log("OCR Starting for:", identityDocumentUrl);

    // تشغيل Tesseract (عربي + إنجليزي)
    const {
      data: { text },
    } = await Tesseract.recognize(
      identityDocumentUrl,
      "ara+eng",
      {
        // logger: m => console.log(m)
      }
    );

    const cleanText = normalizeText(text);

    // استخراج البيانات
    const nationalId = extractJordanNationalId(cleanText);
    const extractedName = extractEnglishName(cleanText); // ✅ إنجليزي فقط

    // حساب ثقة بسيطة
    const confidence =
      nationalId && extractedName ? 0.95 :
      extractedName ? 0.70 :
      nationalId ? 0.70 :
      0.0;

    return {
      nationalId,
      extractedName, // ✅ الاسم الإنجليزي
      rawText: text,
      confidence,
      identityDocumentUrl,
    };
  } catch (error) {
    console.error("OCR Error:", error);
    return {
      nationalId: null,
      extractedName: null,
      rawText: "",
      confidence: 0,
      error: error.message,
    };
  }
}

module.exports = {
  extractNationalIdFromIdentity,
};

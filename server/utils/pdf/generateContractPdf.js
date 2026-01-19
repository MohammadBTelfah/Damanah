const fs = require("fs");
const path = require("path");
const puppeteer = require("puppeteer");
const Handlebars = require("handlebars");

// صياغة تاريخ عربي بسيطة
function formatDate(d) {
  if (!d) return "";
  const date = new Date(d);
  if (Number.isNaN(date.getTime())) return "";
  return `${date.getFullYear()}/${String(date.getMonth() + 1).padStart(
    2,
    "0"
  )}/${String(date.getDate()).padStart(2, "0")}`;
}

function normalizeString(v) {
  return v == null ? "" : String(v);
}

module.exports = async function generateContractPdf(contract, absPdfPath) {
  // 1) اقرأ القالب
  const templatePath = path.join(__dirname, "templates", "contract.hbs");
  // تأكد من وجود ملف القالب في المسار الصحيح
  const templateHtml = fs.readFileSync(templatePath, "utf8");
  const template = Handlebars.compile(templateHtml);

  // 2) جهّز الداتا من الـ populate
  const client = contract.client || {};
  const contractor = contract.contractor || {};
  const project = contract.project || {};

  const data = {
    // عناوين عامة
    contractId: String(contract._id),
    contractDate: formatDate(contract.createdAt || new Date()),

    // صاحب العمل
    clientName: normalizeString(
      client.name || client.fullName || client.username
    ),
    clientPhone: normalizeString(client.phone || client.mobile),
    clientEmail: normalizeString(client.email),
    clientAddress: normalizeString(client.address),

    // المقاول
    contractorName: normalizeString(
      contractor.name || contractor.fullName || contractor.username
    ),
    contractorPhone: normalizeString(contractor.phone || contractor.mobile),
    contractorEmail: normalizeString(contractor.email),
    contractorAddress: normalizeString(contractor.address),

    // المشروع
    projectName: normalizeString(project.name || project.title),
    projectLocation: normalizeString(project.location || project.address),
    projectArea: normalizeString(project.area || project.totalArea),
    projectDescription: normalizeString(contract.projectDescription),

    // القيم المالية والشروط
    agreedPrice: Number(contract.agreedPrice || 0).toLocaleString("en-US"),
    durationMonths: contract.durationMonths ?? "",
    paymentTerms: normalizeString(contract.paymentTerms),
    terms: normalizeString(contract.terms),

    // مواد وخدمات
    materialsAndServices: Array.isArray(contract.materialsAndServices)
      ? contract.materialsAndServices
      : [],

    // تواريخ البداية والنهاية
    startDate: formatDate(contract.startDate),
    endDate: formatDate(contract.endDate),
  };

  const html = template(data);

  // 3) PDF - إعدادات متصفح Puppeteer الخاصة بـ Render
  const browser = await puppeteer.launch({
    headless: "new", // الصيغة الحديثة
    args: [
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--disable-dev-shm-usage", // ✅ ضروري جداً لمنع الكراش بسبب الذاكرة في Render
      "--disable-gpu",
    ],
    // احتياطاً لو أردت تحديد مسار كروم يدوياً مستقبلاً
    executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || null,
  });

  try {
    const page = await browser.newPage();

    // إعداد المحتوى وانتظار تحميل الشبكة (لضمان تحميل الخطوط والصور إن وجدت)
    await page.setContent(html, { waitUntil: "networkidle0" });

    await page.pdf({
      path: absPdfPath, // سيتم الحفظ في المسار الذي تمرره (Temp folder)
      format: "A4",
      printBackground: true,
      margin: { top: "12mm", right: "12mm", bottom: "12mm", left: "12mm" },
    });
  } catch (error) {
    console.error("Error generating PDF with Puppeteer:", error);
    throw error; // ارمِ الخطأ ليعالجه الكونترولر
  } finally {
    // إغلاق المتصفح في كل الأحوال لتجنب استهلاك الذاكرة
    if (browser) {
      await browser.close();
    }
  }
};
const fs = require("fs");
const path = require("path");
const puppeteer = require("puppeteer");
const Handlebars = require("handlebars");

// دالة لتنسيق التاريخ (YYYY/MM/DD)
function formatDate(d) {
  if (!d) return "غير محدد";
  const date = new Date(d);
  if (Number.isNaN(date.getTime())) return "غير محدد";
  return date.toLocaleDateString("en-GB"); // يوم/شهر/سنة
}

// دالة للتأكد من أن النصوص لا تكون null أو undefined
function normalizeString(v) {
  return v ? String(v) : "-";
}

// ✅ دالة ذكية لاختيار الاسم الرسمي
function resolveOfficialName(user = {}) {
  return normalizeString(
    user.fullNameFromId ||               // الاسم المعتمد من المستخدم
    user.identityData?.extractedName ||  // الاسم المستخرج من OCR
    user.name                            // اسم الحساب (fallback أخير)
  );
}

module.exports = async function generateContractPdf(contract, absPdfPath) {
  try {
    // 1) قراءة ملف القالب
    const templatePath = path.join(__dirname, "templates", "contract.hbs");
    const templateHtml = fs.readFileSync(templatePath, "utf8");
    const template = Handlebars.compile(templateHtml);

    // 2) تجهيز البيانات
    const client = contract.client || {};
    const contractor = contract.contractor || {};
    const project = contract.project || {};

    const data = {
      // --- رأس العقد ---
      contractId: String(contract._id).slice(-6),
      contractDate: formatDate(contract.createdAt || new Date()),

      // ✅ الأسماء الرسمية من الهوية (وليس اسم الحساب)
      clientName: resolveOfficialName(client),
      clientNationalId: normalizeString(client.nationalId),

      contractorName: resolveOfficialName(contractor),
      contractorNationalId: normalizeString(contractor.nationalId),

      // --- تفاصيل المشروع ---
      projectName: normalizeString(project.title || project.name),
      projectLocation: normalizeString(project.location || project.address),
      projectArea: normalizeString(project.area || project.totalArea),
      projectDescription: normalizeString(
        contract.projectDescription || project.description
      ),

      // --- المدة ---
      durationMonths: contract.durationMonths
        ? String(contract.durationMonths)
        : "-",
      startDate: formatDate(contract.startDate),
      endDate: formatDate(contract.endDate),

      // --- المال ---
      agreedPrice: Number(contract.agreedPrice || 0).toLocaleString("en-US"),
      paymentTerms: normalizeString(contract.paymentTerms),

      // --- المواد والخدمات ---
      materialsAndServices: contract.materialsAndServices || [],

      // --- الشروط ---
      terms: normalizeString(contract.terms),

      // --- بيانات التواصل ---
      clientPhone: normalizeString(client.phone || client.mobile),
      clientEmail: normalizeString(client.email),
      clientAddress: normalizeString(client.address || client.city),

      contractorPhone: normalizeString(contractor.phone || contractor.mobile),
      contractorEmail: normalizeString(contractor.email),
      contractorAddress: normalizeString(
        contractor.address || contractor.city
      ),
    };

    // 3) توليد HTML
    const html = template(data);

    // 4) تحويل HTML إلى PDF
    const browser = await puppeteer.launch({
      headless: "new",
      args: [
        "--no-sandbox",
        "--disable-setuid-sandbox",
        "--disable-dev-shm-usage",
        "--disable-gpu",
      ],
    });

    const page = await browser.newPage();

    await page.setDefaultNavigationTimeout(60000);
    await page.setContent(html, { waitUntil: "domcontentloaded" });

    await page.pdf({
      path: absPdfPath,
      format: "A4",
      printBackground: true,
      margin: { top: "15mm", right: "10mm", bottom: "15mm", left: "10mm" },
    });

    await browser.close();
    return true;
  } catch (error) {
    console.error("Error generating PDF:", error);
    throw error;
  }
};

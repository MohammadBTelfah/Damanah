const fs = require("fs");
const path = require("path");
const puppeteer = require("puppeteer");
const Handlebars = require("handlebars");

// دالة لتنسيق التاريخ (YYYY/MM/DD)
function formatDate(d) {
  if (!d) return "غير محدد";
  const date = new Date(d);
  if (Number.isNaN(date.getTime())) return "غير محدد";
  return date.toLocaleDateString("en-GB"); // تنسيق يوم/شهر/سنة
}

// دالة للتأكد من أن النصوص لا تكون null أو undefined
function normalizeString(v) {
  return v ? String(v) : "-";
}

module.exports = async function generateContractPdf(contract, absPdfPath) {
  try {
    // 1) قراءة ملف القالب
    // قراءة ملف contract.hbs
    const templatePath = path.join(__dirname, "templates", "contract.hbs");
    const templateHtml = fs.readFileSync(templatePath, "utf8");
    const template = Handlebars.compile(templateHtml);

    // 2) تجهيز البيانات (Mapping)
    // هنا نربط أسماء المتغيرات في hbs بأسماء الحقول في قاعدة البيانات
    const client = contract.client || {};
    const contractor = contract.contractor || {};
    const project = contract.project || {};

    const data = {
      // --- رأس العقد ---
      contractId: String(contract._id).slice(-6), // نأخذ آخر 6 أرقام فقط للجمالية
      contractDate: formatDate(contract.createdAt || new Date()),

      // ✅ التعديل: جلب الاسم الحقيقي المستخرج من الهوية لكل من الطرفين
      clientName: normalizeString(client.identityData?.extractedName || client.name),
      contractorName: normalizeString(contractor.identityData?.extractedName || contractor.name),

      // --- تفاصيل المشروع ---
      projectName: normalizeString(project.title || project.name),
      projectLocation: normalizeString(project.location || project.address),
      // تعبئة مساحة المشروع
      projectArea: normalizeString(project.area || project.totalArea),
      projectDescription: normalizeString(contract.projectDescription || project.description),

      // --- المدة والتواريخ ---
      durationMonths: contract.durationMonths ? String(contract.durationMonths) : "-",
      startDate: formatDate(contract.startDate),
      endDate: formatDate(contract.endDate),

      // --- المال والدفعات ---
      agreedPrice: Number(contract.agreedPrice || 0).toLocaleString("en-US"),
      paymentTerms: normalizeString(contract.paymentTerms),

      // --- المواد والخدمات ---
      // تعبئة قائمة المواد
      materialsAndServices: (() => {
        // 1. الأولوية: إذا كانت المواد محفوظة في العقد، نستخدمها
        if (contract.materialsAndServices && contract.materialsAndServices.length > 0) {
          return contract.materialsAndServices;
        }
        
        // 2. الاحتياط: إذا لم توجد في العقد، نحاول جلبها من تقديرات المشروع (إذا كان المشروع معمولة له populate)
        if (project.estimation && project.estimation.items && project.estimation.items.length > 0) {
          return project.estimation.items.map(item => {
             // تحويل كائن المادة إلى نص مقروء
             return `${item.name} (الكمية: ${item.quantity} ${item.unit || ''})`;
          });
        }

        // 3. إذا لم نجد شيئاً
        return [];
      })(),

      // --- الشروط ---
      // تعبئة الشروط والأحكام
      terms: normalizeString(contract.terms),

      // --- التواقيع والبيانات الشخصية ---
      // بيانات العميل في الجدول
      clientPhone: normalizeString(client.phone || client.mobile),
      clientEmail: normalizeString(client.email),
      clientAddress: normalizeString(client.address || client.city),

      // بيانات المقاول في الجدول
      contractorPhone: normalizeString(contractor.phone || contractor.mobile),
      contractorEmail: normalizeString(contractor.email),
      contractorAddress: normalizeString(contractor.address || contractor.city),
    };

    // 3) توليد HTML النهائي
    const html = template(data);

    // 4) تحويل HTML إلى PDF باستخدام Puppeteer
    const browser = await puppeteer.launch({
      headless: "new",
      args: ["--no-sandbox", "--disable-setuid-sandbox", "--disable-dev-shm-usage", "--disable-gpu"],
    });

    const page = await browser.newPage();
    await page.setContent(html, { waitUntil: "networkidle0" }); // ننتظر تحميل الخطوط

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
const nodemailer = require("nodemailer");

const sendEmail = async ({ to, subject, html }) => {
  try {
    const transporter = nodemailer.createTransport({
      host: "smtp.gmail.com",
      port: 587,              // ✅ نستخدم المنفذ 587 بدلاً من 465
      secure: false,          // ✅ يجب أن تكون false مع المنفذ 587
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
      },
      tls: {
        rejectUnauthorized: false, // ✅ للمساعدة في تخطي مشاكل شهادات الحماية في السيرفرات
        ciphers: 'SSLv3'
      },
      // ✅ تفعيل السجلات لمعرفة سبب الخطأ في Logs الخاصة بـ Render
      logger: true,
      debug: true, 
      connectionTimeout: 10000, 
    });

    // التأكد من الاتصال قبل الإرسال (اختياري للتشخيص)
    await transporter.verify();
    console.log("SMTP Connection Established Successfully");

    await transporter.sendMail({
      from: `"Damana App" <${process.env.EMAIL_USER}>`,
      to,
      subject,
      html,
    });
    console.log("Email sent successfully");

  } catch (error) {
    console.error("Failed to send email:", error);
    // لا نرمي الخطأ لكي لا يوقف السيرفر، أو يمكنك رميه حسب حاجتك
    // throw error; 
  }
};

module.exports = sendEmail;
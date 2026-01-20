const nodemailer = require("nodemailer");

const sendEmail = async ({ to, subject, html }) => {
  try {
    // 🔍 طباعة الإعدادات للتأكد من أن السيرفر قرأ المنفذ 2525
    console.log("🛠️ Email Config Check:", {
      host: process.env.EMAIL_HOST,
      port: process.env.EMAIL_PORT,
      user: process.env.EMAIL_USER,
    });

    const transporter = nodemailer.createTransport({
      host: process.env.EMAIL_HOST, // ✅ يقرأ من Env (smtp-relay.brevo.com)
      port: process.env.EMAIL_PORT, // ✅ يقرأ من Env (يجب أن يكون 2525)
      secure: false,                  // ✅ يجب أن يكون false مع 2525 أو 587
      auth: {
        user: process.env.EMAIL_USER, // ✅ اسم مستخدم Brevo
        pass: process.env.EMAIL_PASS, // ✅ كلمة مرور Brevo
      },
      // ⏳ إعدادات المهلة لمنع تعليق السيرفر
      connectionTimeout: 10000, // 10 ثواني
      greetingTimeout: 5000,    // 5 ثواني
    });

    // 📧 الإيميل الذي سيظهر للمستلم (إيميلك الحقيقي)
    const senderEmail = "telfahmohammad2003@gmail.com"; 

    await transporter.sendMail({
      from: `"Damana App" <${senderEmail}>`, 
      to,
      subject,
      html,
    });
    console.log("✅ Email sent successfully via Brevo");

  } catch (error) {
    console.error("❌ Failed to send email:", error.message);
  }
};

module.exports = sendEmail;
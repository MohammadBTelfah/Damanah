const nodemailer = require("nodemailer");

const sendEmail = async ({ to, subject, html }) => {
  try {
    const transporter = nodemailer.createTransport({
      host: process.env.EMAIL_HOST, // ✅ سيقرأ: smtp-relay.brevo.com
      port: process.env.EMAIL_PORT, // ✅ سيقرأ: 587
      secure: false,                  // ✅ إعداد صحيح للمنفذ 587
      auth: {
        user: process.env.EMAIL_USER, // ✅ اسم مستخدم Brevo
        pass: process.env.EMAIL_PASS, // ✅ كلمة مرور Brevo
      },
      // إعدادات المهلة لمنع تعليق السيرفر
      connectionTimeout: 10000, 
      greetingTimeout: 5000,
    });

    // ⚠️ نقطة مهمة:
    // Brevo يستخدم EMAIL_USER للدخول فقط (Login)، لكنه يسمح لك بالإرسال من إيميلك الشخصي
    // ضع إيميلك هنا ليظهر للمستلم بشكل احترافي
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
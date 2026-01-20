const nodemailer = require("nodemailer");

const sendEmail = async ({ to, subject, html }) => {
  // ✅ التعديل: استخدام إعدادات صريحة (host, port, secure) بدلاً من service: "gmail"
  const transporter = nodemailer.createTransport({
    host: "smtp.gmail.com", // سيرفر جوجل
    port: 465,              // منفذ SSL (مفتوح في Render)
    secure: true,           // ضروري مع منفذ 465
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
    // ✅ إعدادات إضافية لمنع التايم أوت
    connectionTimeout: 10000, // 10 ثواني كحد أقصى للاتصال
    greetingTimeout: 5000,    // 5 ثواني لانتظار ترحيب السيرفر
    socketTimeout: 10000,     // 10 ثواني لانتظار البيانات
  });

  await transporter.sendMail({
    from: `"Damana App" <${process.env.EMAIL_USER}>`,
    to,
    subject,
    html,
  });
};

module.exports = sendEmail;
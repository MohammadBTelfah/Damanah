const rateLimit = require("express-rate-limit");

exports.forgotPasswordLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 3,
  message: { message: "Too many OTP requests. Try again later." },
  standardHeaders: true,
  legacyHeaders: false,
});

exports.resetPasswordLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 8,
  message: { message: "Too many reset attempts. Try again later." },
  standardHeaders: true,
  legacyHeaders: false,
});
module.exports = exports;
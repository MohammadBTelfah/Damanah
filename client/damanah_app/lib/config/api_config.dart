import 'package:flutter/foundation.dart';

class ApiConfig {
  // ✅ الرابط الجديد للسيرفر المرفوع
  // ملاحظة: لا نضع slash (/) في النهاية
  static const String baseUrl = 'https://damanah.onrender.com';

  static String join(String path) {
    // التأكد من عدم تكرار الـ slash
    final b = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final p = path.startsWith('/') ? path.substring(1) : path;
    return '$b/$p';
  }
}
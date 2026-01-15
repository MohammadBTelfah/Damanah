import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _lanIp = '192.168.1.14'; // IP الكمبيوتر داخل الشبكة
  static const bool _useEmulator =
      bool.fromEnvironment('USE_EMULATOR', defaultValue: false);

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000';

    // Android Emulator
    if (Platform.isAndroid && _useEmulator) {
      return 'http://10.0.2.2:5000';
    }

    // جهاز حقيقي
    return 'http://$_lanIp:5000';
  }

  static String join(String path) {
    final b = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final p = path.startsWith('/') ? path.substring(1) : path;
    return '$b/$p';
  }
}

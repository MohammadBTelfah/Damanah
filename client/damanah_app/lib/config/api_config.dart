import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // ✅ IP الكمبيوتر الحقيقي (من ipconfig)
  static const String _lanIp = '192.168.1.14';

  /// شغّل Emulator هكذا:
  /// flutter run --dart-define=USE_EMULATOR=true
  ///
  /// شغّل Mobile حقيقي:
  /// flutter run --dart-define=USE_EMULATOR=false
  static const bool _useEmulator =
      bool.fromEnvironment('USE_EMULATOR', defaultValue: false);

  /// Base URL حسب المنصّة
  static String get baseUrl {
    // 🌐 Web (Chrome)
    if (kIsWeb) {
      return 'http://localhost:5000';
    }

    // 🤖 Android Emulator
    if (Platform.isAndroid && _useEmulator) {
      return 'http://10.0.2.2:5000';
    }

    // 📱 Android real device / iOS
    return 'http://$_lanIp:5000';
  }

  /// Join helper
  static String join(String path) {
    final b = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final p = path.startsWith('/') ? path.substring(1) : path;
    return "$b/$p";
  }
}

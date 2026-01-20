import 'dart:convert';
import 'dart:io'; // ✅ مطلوب للتعامل مع الملفات
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart'; // ✅ مكتبة ضغط الصور
import 'package:path/path.dart' as p; // للمساعدة في معرفة الامتداد (اختياري، استخدمت طريقة يدوية أدناه لتقليل الاعتمادات)

import '../config/api_config.dart';

class AuthService {
  // ✅ Auth routes
  static String get _clientAuthBaseUrl => ApiConfig.join('/api/auth/client');
  static String get _contractorAuthBaseUrl => ApiConfig.join('/api/auth/contractor');

  // ✅ Account routes
  static String get _clientAccountBaseUrl => ApiConfig.join('/api/client/account');
  static String get _contractorAccountBaseUrl => ApiConfig.join('/api/contractor/account');

  // ⏳ مهلة الاتصال الافتراضية (60 ثانية للرفع، 30 ثانية للطلبات العادية)
  static const Duration _uploadTimeout = Duration(seconds: 60);
  static const Duration _requestTimeout = Duration(seconds: 30);

  /* ===================== HELPER: IMAGE COMPRESSION ===================== */

  /// ✅ دالة مساعدة لضغط الصور قبل الرفع
  /// - تتجاهل ملفات PDF وتعيدها كما هي.
  /// - تضغط الصور (JPG, PNG) لتقليل حجمها.
  Future<String> _compressFileIfNeeded(String filePath) async {
    // 1. إذا كان الملف PDF، لا تضغطه
    if (filePath.toLowerCase().endsWith('.pdf')) {
      return filePath;
    }

    try {
      final file = File(filePath);
      if (!file.existsSync()) return filePath;

      // تحديد مسار للملف المضغوط
      final lastIndex = filePath.lastIndexOf(RegExp(r'\.'));
      if (lastIndex == -1) return filePath; // لا يوجد امتداد معروف
      
      final basePath = filePath.substring(0, lastIndex);
      final extension = filePath.substring(lastIndex);
      final targetPath = '${basePath}_compressed$extension';

      // 2. محاولة الضغط
      var result = await FlutterImageCompress.compressAndGetFile(
        filePath,
        targetPath,
        quality: 70, // جودة 70 ممتازة للموازنة بين الوضوح والحجم
        minWidth: 1024, // تقليص الأبعاد إذا كانت ضخمة جداً
        minHeight: 1024,
      );

      return result?.path ?? filePath;
    } catch (e) {
      // في حال حدوث أي خطأ في الضغط، نستخدم الملف الأصلي
      print("Compression failed: $e");
      return filePath;
    }
  }

  /* ===================== CLIENT ===================== */

  Future<Map<String, dynamic>> loginClient({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$_clientAuthBaseUrl/login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(_requestTimeout); // ✅ إضافة Timeout

    final data = _safeJson(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Login failed');
  }

  Future<Map<String, dynamic>> registerClient({
    required String name,
    required String email,
    required String password,
    required String phone,
    String? profileImagePath,
    String? identityFilePath,
    String? nationalId,
  }) async {
    final uri = Uri.parse('$_clientAuthBaseUrl/register');
    final request = http.MultipartRequest('POST', uri);

    request.fields['name'] = name;
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.fields['phone'] = phone;

    if (nationalId != null && nationalId.trim().isNotEmpty) {
      request.fields['nationalId'] = nationalId.trim();
    }

    // ✅ ضغط ورفع الصورة الشخصية
    if (profileImagePath != null && profileImagePath.isNotEmpty) {
      final compressedPath = await _compressFileIfNeeded(profileImagePath);
      request.files.add(
        await http.MultipartFile.fromPath('profileImage', compressedPath),
      );
    }

    // ✅ ضغط ورفع الهوية (إذا كانت صورة)
    if (identityFilePath != null && identityFilePath.isNotEmpty) {
      final compressedPath = await _compressFileIfNeeded(identityFilePath);
      request.files.add(
        await http.MultipartFile.fromPath('identityDocument', compressedPath),
      );
    }

    final streamed = await request.send().timeout(_uploadTimeout); // ✅ مهلة أطول للرفع
    final response = await http.Response.fromStream(streamed);

    final data = _safeJson(response.body);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? 'Registration failed');
  }

  Future<Map<String, dynamic>> resendClientVerificationEmail({
    required String email,
  }) async {
    final url = Uri.parse('$_clientAuthBaseUrl/resend-verification-email');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    ).timeout(_requestTimeout);

    final data = _safeJson(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Resend failed');
  }

  /// ✅ GET /api/client/account/me
  Future<Map<String, dynamic>> getMeClient({required String token}) async {
    final url = Uri.parse('$_clientAccountBaseUrl/me');

    final res = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    ).timeout(_requestTimeout);

    final data = _safeJson(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data["message"] ?? "Get me failed");
  }

  /// ✅ Login ثم getMe
  Future<Map<String, dynamic>> loginAndGetSessionClient({
    required String email,
    required String password,
  }) async {
    final login = await loginClient(email: email, password: password);

    final token = login["token"];
    if (token == null || token.toString().isEmpty) {
      throw Exception("No token returned from login");
    }

    final me = await getMeClient(token: token.toString());
    final user = me["user"];
    if (user == null || user is! Map) {
      throw Exception("Invalid /me response");
    }

    return {
      "token": token.toString(),
      "user": Map<String, dynamic>.from(user),
    };
  }

  // ✅ Forgot Password (Client)
  Future<Map<String, dynamic>> forgotPasswordClient({
    required String email,
  }) async {
    final url = Uri.parse('$_clientAccountBaseUrl/forgot-password');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': 'client',
        'email': email,
      }),
    ).timeout(_requestTimeout);

    final data = _safeJson(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Forgot password failed');
  }

  // ✅ Reset Password (Client)
  Future<Map<String, dynamic>> resetPasswordClient({
    required String otp,
    required String newPassword,
  }) async {
    final url = Uri.parse('$_clientAccountBaseUrl/reset-password');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': 'client',
        'otp': otp,
        'newPassword': newPassword,
      }),
    ).timeout(_requestTimeout);

    final data = _safeJson(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Reset password failed');
  }

  /* ===================== CONTRACTOR ===================== */

  Future<Map<String, dynamic>> loginContractor({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$_contractorAuthBaseUrl/login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(_requestTimeout);

    final data = _safeJson(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Login failed');
  }

  Future<Map<String, dynamic>> registerContractor({
    required String name,
    required String email,
    required String password,
    required String phone,
    String? profileImagePath,
    String? identityFilePath,
    required String contractorFilePath,
    String? nationalId,
  }) async {
    final uri = Uri.parse('$_contractorAuthBaseUrl/register');
    final request = http.MultipartRequest('POST', uri);

    request.fields['name'] = name;
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.fields['phone'] = phone;

    if (nationalId != null && nationalId.trim().isNotEmpty) {
      request.fields['nationalId'] = nationalId.trim();
    }

    // ✅ ضغط ورفع الصورة الشخصية
    if (profileImagePath != null && profileImagePath.isNotEmpty) {
      final compressedPath = await _compressFileIfNeeded(profileImagePath);
      request.files.add(
        await http.MultipartFile.fromPath('profileImage', compressedPath),
      );
    }

    // ✅ ضغط ورفع الهوية
    if (identityFilePath != null && identityFilePath.isNotEmpty) {
      final compressedPath = await _compressFileIfNeeded(identityFilePath);
      request.files.add(
        await http.MultipartFile.fromPath('identityDocument', compressedPath),
      );
    }

    // ✅ ضغط ورفع وثيقة المقاول (إذا لم تكن PDF)
    // ملاحظة: المقاول قد يرفع رخصة PDF، الدالة _compressFileIfNeeded تتجاهلها تلقائياً
    if (contractorFilePath.isNotEmpty) {
      final compressedPath = await _compressFileIfNeeded(contractorFilePath);
      request.files.add(
        await http.MultipartFile.fromPath(
          'contractorDocument',
          compressedPath,
        ),
      );
    }

    final streamed = await request.send().timeout(_uploadTimeout);
    final response = await http.Response.fromStream(streamed);

    final data = _safeJson(response.body);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? 'Registration failed');
  }

  Future<Map<String, dynamic>> resendContractorVerificationEmail({
    required String email,
  }) async {
    final url = Uri.parse('$_contractorAuthBaseUrl/resend-verification-email');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    ).timeout(_requestTimeout);

    final data = _safeJson(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Resend failed');
  }

  /// ✅ GET /api/contractor/account/me
  Future<Map<String, dynamic>> getMeContractor({required String token}) async {
    final url = Uri.parse('$_contractorAccountBaseUrl/me');

    final res = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    ).timeout(_requestTimeout);

    final data = _safeJson(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data["message"] ?? "Get me failed");
  }

  /// ✅ Login ثم getMe
  Future<Map<String, dynamic>> loginAndGetSessionContractor({
    required String email,
    required String password,
  }) async {
    final login = await loginContractor(email: email, password: password);

    final token = login["token"];
    if (token == null || token.toString().isEmpty) {
      throw Exception("No token returned from login");
    }

    final me = await getMeContractor(token: token.toString());
    final user = me["user"];
    if (user == null || user is! Map) {
      throw Exception("Invalid /me response");
    }

    return {
      "token": token.toString(),
      "user": Map<String, dynamic>.from(user),
    };
  }

  // ✅ Forgot Password (Contractor)
  Future<Map<String, dynamic>> forgotPasswordContractor({
    required String email,
  }) async {
    final url = Uri.parse('$_contractorAccountBaseUrl/forgot-password');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': 'contractor',
        'email': email,
      }),
    ).timeout(_requestTimeout);

    final data = _safeJson(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Forgot password failed');
  }

  // ✅ Reset Password (Contractor)
  Future<Map<String, dynamic>> resetPasswordContractor({
    required String otp,
    required String newPassword,
  }) async {
    final url = Uri.parse('$_contractorAccountBaseUrl/reset-password');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': 'contractor',
        'otp': otp,
        'newPassword': newPassword,
      }),
    ).timeout(_requestTimeout);

    final data = _safeJson(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Reset password failed');
  }

  /* ===================== Helper ===================== */

  Map<String, dynamic> _safeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'message': 'Invalid server response'};
    } catch (_) {
      return {'message': 'Invalid server response'};
    }
  }
}
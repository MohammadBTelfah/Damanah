import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // ✅ خلي كل المشروع يستخدم نفس الـ baseUrl
  // Emulator: 10.0.2.2
  static const String _baseUrl = 'http://10.0.2.2:5000';

  // Auth routes (login/register/verification)
  static const String _clientAuthBaseUrl = '$_baseUrl/api/auth/client';
  static const String _contractorAuthBaseUrl = '$_baseUrl/api/auth/contractor';

  // Account routes (me/change-password/forgot/reset)
  static const String _clientAccountBaseUrl = '$_baseUrl/api/client/account';
  static const String _contractorAccountBaseUrl =
      '$_baseUrl/api/contractor/account';

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
    );

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
    double? nationalIdConfidence,
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
    if (nationalIdConfidence != null) {
      request.fields['nationalIdConfidence'] = nationalIdConfidence.toString();
    }

    if (profileImagePath != null && profileImagePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('profileImage', profileImagePath),
      );
    }

    if (identityFilePath != null && identityFilePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('identityDocument', identityFilePath),
      );
    }

    final streamed = await request.send();
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
    );

    final data = _safeJson(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Resend failed');
  }

  /// ✅ GET /api/client/account/me  (بيرجع user وفيه role)
  Future<Map<String, dynamic>> getMeClient({required String token}) async {
    final url = Uri.parse('$_clientAccountBaseUrl/me');

    final res = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    final data = _safeJson(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data["message"] ?? "Get me failed");
  }

  /// ✅ Login ثم getMe (ترجع token + user جاهزين للحفظ)
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
      "user": Map<String, dynamic>.from(user as Map),
    };
  }

  // ✅ Forgot Password (Client) - OTP
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
    );

    final data = _safeJson(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Forgot password failed');
  }

  // ✅ Reset Password (Client) - OTP
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
    );

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
    );

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
    double? nationalIdConfidence,
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
    if (nationalIdConfidence != null) {
      request.fields['nationalIdConfidence'] = nationalIdConfidence.toString();
    }

    if (profileImagePath != null && profileImagePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('profileImage', profileImagePath),
      );
    }

    if (identityFilePath != null && identityFilePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('identityDocument', identityFilePath),
      );
    }

    request.files.add(
      await http.MultipartFile.fromPath('contractorDocument', contractorFilePath),
    );

    final streamed = await request.send();
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
    );

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
    );

    final data = _safeJson(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data["message"] ?? "Get me failed");
  }

  /// ✅ Login ثم getMe (ترجع token + user جاهزين للحفظ)
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
      "user": Map<String, dynamic>.from(user as Map),
    };
  }

  // ✅ Forgot Password (Contractor) - OTP
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
    );

    final data = _safeJson(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Forgot password failed');
  }

  // ✅ Reset Password (Contractor) - OTP
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
    );

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

import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _clientBaseUrl =
      'http://192.168.1.14:5000/api/auth/client';
  static const String _contractorBaseUrl =
      'http://192.168.1.14:5000/api/auth/contractor';

  // ===================== CLIENT =====================

  // ===== Client Login =====
  Future<Map<String, dynamic>> loginClient({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$_clientBaseUrl/login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = _safeJson(response.body);

    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Login failed');
  }

  // ===== Client Register =====
  Future<Map<String, dynamic>> registerClient({
    required String name,
    required String email,
    required String password,
    required String phone,

    // files
    String? profileImagePath, // profileImage (optional)
    String? identityFilePath, // identityDocument (optional بالباك اند - بس انتي بتخليها اجباري)

    // بدك يضلوا
    String? nationalId,
    double? nationalIdConfidence,
  }) async {
    final uri = Uri.parse('$_clientBaseUrl/register');
    final request = http.MultipartRequest('POST', uri);

    request.fields['name'] = name;
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.fields['phone'] = phone;

    // optional fields (backend قد يتجاهلهم إذا OCR فقط)
    if (nationalId != null && nationalId.trim().isNotEmpty) {
      request.fields['nationalId'] = nationalId.trim();
    }
    if (nationalIdConfidence != null) {
      request.fields['nationalIdConfidence'] = nationalIdConfidence.toString();
    }

    // profileImage optional
    if (profileImagePath != null && profileImagePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('profileImage', profileImagePath),
      );
    }

    // identityDocument optional
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
    } else {
      throw Exception(data['message'] ?? 'Registration failed');
    }
  }

  // (اختياري) Resend client verification email
  Future<Map<String, dynamic>> resendClientVerificationEmail({
    required String email,
  }) async {
    final url = Uri.parse('$_clientBaseUrl/resend-verification-email');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final data = _safeJson(response.body);

    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Resend failed');
  }

  // ===================== CONTRACTOR =====================

  // ===== Contractor Login =====
  Future<Map<String, dynamic>> loginContractor({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$_contractorBaseUrl/login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = _safeJson(response.body);

    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Login failed');
  }

  // ===== Contractor Register =====
  // ✅ مطابق للكونترولر اللي عندك (profile + identity + contractorDocument)
  Future<Map<String, dynamic>> registerContractor({
    required String name,
    required String email,
    required String password,
    required String phone,

    // files
    String? profileImagePath, // profileImage (optional)
    String? identityFilePath, // identityDocument (optional بالباك اند - بس انتي بتخليها اجباري)
    required String contractorFilePath, // contractorDocument

    // بدك يضلوا
    String? nationalId,
    double? nationalIdConfidence,
  }) async {
    final uri = Uri.parse('$_contractorBaseUrl/register');
    final request = http.MultipartRequest('POST', uri);

    request.fields['name'] = name;
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.fields['phone'] = phone;

    // optional fields (backend قد يتجاهلهم إذا OCR فقط)
    if (nationalId != null && nationalId.trim().isNotEmpty) {
      request.fields['nationalId'] = nationalId.trim();
    }
    if (nationalIdConfidence != null) {
      request.fields['nationalIdConfidence'] = nationalIdConfidence.toString();
    }

    // profileImage optional
    if (profileImagePath != null && profileImagePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('profileImage', profileImagePath),
      );
    }

    // identityDocument optional
    if (identityFilePath != null && identityFilePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('identityDocument', identityFilePath),
      );
    }

    // contractorDocument required
    request.files.add(
      await http.MultipartFile.fromPath(
        'contractorDocument',
        contractorFilePath,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    final data = _safeJson(response.body);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Registration failed');
    }
  }

  // (اختياري) Resend contractor verification email
  Future<Map<String, dynamic>> resendContractorVerificationEmail({
    required String email,
  }) async {
    final url = Uri.parse('$_contractorBaseUrl/resend-verification-email');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final data = _safeJson(response.body);

    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Resend failed');
  }

  // ===================== Helper =====================

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

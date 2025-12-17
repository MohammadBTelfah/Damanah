import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // على Android Emulator نستخدم 10.0.2.2
  static const String _baseUrl = 'http://10.0.2.2:5000/api/auth';

  // ===== Login =====
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$_baseUrl/login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data as Map<String, dynamic>;
    } else {
      throw Exception(data['message'] ?? 'Login failed');
    }
  }

  // ===== Client Register (مع ملف هوية + صورة اختيارية) =====
  Future<Map<String, dynamic>> registerClient({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String identityFilePath, // path للملف
    String? profileImagePath, // ✅ اختياري (بدون required)
  }) async {
    final uri = Uri.parse('$_baseUrl/register');
    final request = http.MultipartRequest('POST', uri);

    request.fields['name'] = name;
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.fields['phone'] = phone;
    request.fields['role'] = 'client';

    // صورة البروفايل (اختياري)
    if (profileImagePath != null && profileImagePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'profileImage',
          profileImagePath,
        ),
      );
    }

    // ملف الهوية (إجباري)
    request.files.add(
      await http.MultipartFile.fromPath(
        'identityDocument',
        identityFilePath,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    final data = jsonDecode(response.body);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return data as Map<String, dynamic>;
    } else {
      throw Exception(data['message'] ?? 'Registration failed');
    }
  }

  // ===== Contractor Register (هوية + وثيقة مقاول + صورة اختيارية) =====
  Future<Map<String, dynamic>> registerContractor({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String identityFilePath, // الهوية
    required String contractorFilePath, // وثيقة المقاول
    String? profileImagePath, // صورة اختيارية
  }) async {
    final uri = Uri.parse('$_baseUrl/register');
    final request = http.MultipartRequest('POST', uri);

    request.fields['name'] = name;
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.fields['phone'] = phone;
    request.fields['role'] = 'contractor'; // ✅ مهم

    // صورة البروفايل (اختياري)
    if (profileImagePath != null && profileImagePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'profileImage',
          profileImagePath,
        ),
      );
    }

    // الهوية (إجباري)
    request.files.add(
      await http.MultipartFile.fromPath(
        'identityDocument',
        identityFilePath,
      ),
    );

    // وثيقة المقاول (إجباري)
    request.files.add(
      await http.MultipartFile.fromPath(
        'contractorDocument',
        contractorFilePath,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    final data = jsonDecode(response.body);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return data as Map<String, dynamic>;
    } else {
      throw Exception(data['message'] ?? 'Registration failed');
    }
  }
}

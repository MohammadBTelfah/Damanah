import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // على Android Emulator نستخدم 10.0.2.2
  static const String _baseUrl = 'http://10.0.2.2:5000/api/auth';

  // ===== Login موجود سابقاً =====
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

  // ===== Client Register (مع ملف هوية) =====
  Future<Map<String, dynamic>> registerClient({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String identityFilePath, // path للملف
  }) async {
    final uri = Uri.parse('$_baseUrl/register');

    final request = http.MultipartRequest('POST', uri);

    // fields العادية
    request.fields['name'] = name;
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.fields['phone'] = phone;
    request.fields['role'] = 'client'; // مهم جداً

    // ملف الهوية
    request.files.add(
      await http.MultipartFile.fromPath(
        'identityDocument', // نفس الاسم في multer
        identityFilePath,
      ),
    );

    // ملاحظة: ما بنبعت contractorDocument عشان هو Client

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

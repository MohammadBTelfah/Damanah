import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // لو على Android Emulator استخدم 10.0.2.2 بدل localhost
  static const String _baseUrl = 'http://10.0.2.2:5000/api/auth';

  // تقدر تغيّرها لـ localhost لو بتشغل على Web أو جهاز حقيقي
  // static const String _baseUrl = 'http://localhost:5000/api/auth';

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
      // متوقع يرجّع: message, token, user
      return data as Map<String, dynamic>;
    } else {
      throw Exception(data['message'] ?? 'Login failed');
    }
  }
}

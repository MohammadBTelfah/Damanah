import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/session_service.dart';

class UserService {
  static const String baseUrl = "http://10.0.2.2:5000";

  // ✅ PATCH /api/user/me (multipart)
  Future<Map<String, dynamic>> updateMe({
    required String name,
    required String phone,
    String? profileImagePath,
  }) async {
    final token = await SessionService.getToken();
    final uri = Uri.parse("$baseUrl/api/user/me");

    final request = http.MultipartRequest("PATCH", uri);

    if (token != null) {
      request.headers["Authorization"] = "Bearer $token";
    }

    request.fields["name"] = name;
    request.fields["phone"] = phone;

    if (profileImagePath != null && profileImagePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          "profileImage", // ✅ لازم يطابق multer
          profileImagePath,
        ),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data as Map<String, dynamic>;
    throw Exception(data["message"] ?? "Update profile failed");
  }

  // ✅ POST /api/user/change-password
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await SessionService.getToken();
    final uri = Uri.parse("$baseUrl/api/user/change-password");

    final res = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "currentPassword": currentPassword,
        "newPassword": newPassword,
      }),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data as Map<String, dynamic>;
    throw Exception(data["message"] ?? "Change password failed");
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/session_service.dart';

class UserService {
  static const String baseUrl = "http://10.0.2.2:5000";

  Future<String> _accountBasePath() async {
    final user = await SessionService.getUser();
    final role = (user?["role"] ?? "").toString().trim().toLowerCase();

    if (role == "client") return "/api/client/account";
    if (role == "contractor") return "/api/contractor/account";
    if (role == "admin") return "/api/admin/account";

    throw Exception("Unknown role. Cannot resolve account routes.");
  }

  bool _looksLikeJson(String body) {
    final t = body.trimLeft();
    return t.startsWith("{") || t.startsWith("[");
  }

  Exception _serverException(int status, String body) {
    final firstLine = body.split('\n').first.trim();
    // اختصر الرسالة إذا كانت HTML
    if (firstLine.startsWith("<!DOCTYPE") || firstLine.startsWith("<html")) {
      return Exception("Server error ($status). (HTML response)");
    }
    return Exception("Server error ($status): $firstLine");
  }

  // ✅ PUT {role}/account/me (multipart)
  Future<Map<String, dynamic>> updateMe({
    required String name,
    required String phone,
    String? profileImagePath,
  }) async {
    final token = await SessionService.getToken();
    final basePath = await _accountBasePath();
    final uri = Uri.parse("$baseUrl$basePath/me");

    // ✅ لازم PUT (مش PATCH)
    final request = http.MultipartRequest("PUT", uri);

    if (token != null) {
      request.headers["Authorization"] = "Bearer $token";
    }

    request.fields["name"] = name;
    request.fields["phone"] = phone;

    if (profileImagePath != null && profileImagePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          "profileImage",
          profileImagePath,
        ),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    final body = response.body;

    debugPrint("UPDATE ME URL: $uri");
    debugPrint("UPDATE ME STATUS: ${response.statusCode}");
    debugPrint("UPDATE ME BODY: $body");

    // ✅ إذا السيرفر رجّع HTML أو نص غير JSON
    if (!_looksLikeJson(body)) {
      throw _serverException(response.statusCode, body);
    }

    final decoded = jsonDecode(body);

    // أغلب ردودك Map
    final data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    if (response.statusCode == 200) return data;

    throw Exception(data["message"] ?? "Update profile failed");
  }

  // ✅ PUT {role}/account/change-password
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await SessionService.getToken();
    final basePath = await _accountBasePath();
    final uri = Uri.parse("$baseUrl$basePath/change-password");

    final res = await http.put(
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

    debugPrint("CHANGE PASS URL: $uri");
    debugPrint("CHANGE PASS STATUS: ${res.statusCode}");
    debugPrint("CHANGE PASS BODY: ${res.body}");

    if (!_looksLikeJson(res.body)) {
      throw _serverException(res.statusCode, res.body);
    }

    final data = jsonDecode(res.body);
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};

    if (res.statusCode == 200) return map;

    throw Exception(map["message"] ?? "Change password failed");
  }
}

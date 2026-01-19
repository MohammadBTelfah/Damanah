import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/session_service.dart';
import '../config/api_config.dart';

class UserService {
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
    if (firstLine.startsWith("<!DOCTYPE") || firstLine.startsWith("<html")) {
      return Exception("Server error ($status). (HTML response)");
    }
    return Exception("Server error ($status): $firstLine");
  }

  // ✅ PUT {role}/account/me (multipart)
  // تم التأكد من أن المسار يستخدم ApiConfig.join للربط مع سيرفر Render
  Future<Map<String, dynamic>> updateMe({
    required String name,
    required String phone,
    String? profileImagePath,
  }) async {
    final token = await SessionService.getToken();
    final basePath = await _accountBasePath();

    // ✅ استخدام الإعدادات المركزية للروابط لضمان الاتصال بـ Render
    final uri = Uri.parse(ApiConfig.join("$basePath/me"));

    final request = http.MultipartRequest("PUT", uri);

    if (token != null && token.isNotEmpty) {
      request.headers["Authorization"] = "Bearer $token";
    }

    request.fields["name"] = name;
    request.fields["phone"] = phone;

    if (profileImagePath != null && profileImagePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath("profileImage", profileImagePath),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    final body = response.body;

    debugPrint("UPDATE ME URL: $uri");
    debugPrint("UPDATE ME STATUS: ${response.statusCode}");
    debugPrint("UPDATE ME BODY: $body");

    if (!_looksLikeJson(body)) {
      throw _serverException(response.statusCode, body);
    }

    final decoded = jsonDecode(body);
    final data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    if (response.statusCode == 200) {
      // ✅ ملاحظة: الباك إند سيرجع الآن رابط Cloudinary كامل في الحقل profileImage
      return data;
    }

    throw Exception(data["message"] ?? "Update profile failed");
  }

  // ✅ PUT {role}/account/change-password
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await SessionService.getToken();
    final basePath = await _accountBasePath();

    // ✅ التوجيه إلى سيرفر Render عبر ApiConfig
    final uri = Uri.parse(ApiConfig.join("$basePath/change-password"));

    final res = await http.put(
      uri,
      headers: {
        "Content-Type": "application/json",
        if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
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

    final decoded = jsonDecode(res.body);
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    if (res.statusCode == 200) return map;

    throw Exception(map["message"] ?? "Change password failed");
  }
}
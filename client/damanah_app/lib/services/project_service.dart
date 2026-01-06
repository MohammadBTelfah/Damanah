import 'dart:convert';
import 'package:http/http.dart' as http;

import 'session_service.dart';

class ProjectService {
  final String baseUrl = "http://10.0.2.2:5000";

  Map<String, dynamic> _safeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {"message": "Invalid server response"};
    } catch (_) {
      return {"message": "Invalid server response"};
    }
  }

  // ✅ إنشاء مشروع (بيرجع response كامل: {message, project})
  Future<Map<String, dynamic>> createProject({
    required String title,
    required String description,
    required String location,
    required double area,
    required int floors,
    required String finishingLevel,
  }) async {
    final token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("No token. Please login again.");
    }

    final url = Uri.parse("$baseUrl/api/projects");

    final res = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "title": title,
        "description": description,
        "location": location,
        "area": area,
        "floors": floors,
        "finishingLevel": finishingLevel,
      }),
    );

    final data = _safeJson(res.body);

    if (res.statusCode == 201) {
      return data;
    }

    throw Exception(data["message"] ?? "Failed to create project");
  }

  // ✅ هاي اللي كانت ناقصتك: ترجع projectId مباشرة
  Future<String> createProjectAndReturnId({
    required String title,
    required String description,
    required String location,
    required double area,
    required int floors,
    required String finishingLevel,
  }) async {
    final data = await createProject(
      title: title,
      description: description,
      location: location,
      area: area,
      floors: floors,
      finishingLevel: finishingLevel,
    );

    final project = data["project"];
    final id = (project is Map) ? project["_id"] : null;

    if (id == null) {
      throw Exception("Project created but missing id");
    }

    return id.toString();
  }

  // ✅ Upload Plan (Multipart) على: /api/projects/:projectId/plan
  Future<Map<String, dynamic>> uploadPlan({
    required String projectId,
    required String filePath,
  }) async {
    final token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("No token. Please login again.");
    }

    final uri = Uri.parse("$baseUrl/api/projects/$projectId/plan");
    final request = http.MultipartRequest("POST", uri);

    request.headers["Authorization"] = "Bearer $token";

    // اسم الفيلد لازم يطابق upload.single("plan") بالباك
request.files.add(await http.MultipartFile.fromPath("planFile", filePath));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    final data = _safeJson(res.body);

    if (res.statusCode == 200) return data;

    throw Exception(data["message"] ?? "Upload failed");
  }
}

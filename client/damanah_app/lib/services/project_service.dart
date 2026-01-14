import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/session_service.dart';

class ProjectService {
  static const String baseUrl = "http://10.0.2.2:5000";

  String _join(String path) {
    final b = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final p = path.startsWith('/') ? path.substring(1) : path;
    return "$b/$p";
  }

  Map<String, dynamic> _safeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {"message": "Invalid server response"};
    } catch (_) {
      return {"message": "Invalid server response", "raw": body};
    }
  }

  Future<String> _mustToken() async {
    final token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("No token. Please login again.");
    }
    return token;
  }

  /// POST /api/projects/plan/analyze (multipart planFile)
  Future<Map<String, dynamic>> analyzePlan({required String filePath}) async {
    final token = await _mustToken();
    final uri = Uri.parse(_join("/api/projects/plan/analyze"));

    final req = http.MultipartRequest("POST", uri);
    req.headers.addAll({
      "Authorization": "Bearer $token",
      "Accept": "application/json",
    });

    req.files.add(await http.MultipartFile.fromPath("planFile", filePath));

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);

    final data = _safeJson(res.body);

    if (res.statusCode == 200) return data;

    final code = data["code"]?.toString();
    if (code == "AI_UNAVAILABLE") {
      throw Exception("AI_UNAVAILABLE");
    }

    throw Exception(
      "(${res.statusCode}) ${data["message"] ?? "Analyze plan failed"}",
    );
  }

  /// POST /api/projects
  Future<String> createProjectAndReturnId({
    required String title,
    String? description,
    String? location,
    required double area,
    required int floors,
    required String finishingLevel,
    Map<String, dynamic>? planAnalysis,
  }) async {
    final token = await _mustToken();
    final uri = Uri.parse(_join("/api/projects"));

    final body = {
      "title": title,
      "description": description ?? "",
      "location": location ?? "",
      "area": area,
      "floors": floors,
      "finishingLevel": finishingLevel,
      if (planAnalysis != null) "planAnalysis": planAnalysis,
    };

    final res = await http
        .post(
          uri,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));

    final data = _safeJson(res.body);

    if (res.statusCode == 200 || res.statusCode == 201) {
      final project = data["project"];
      final id = project?["_id"]?.toString();
      if (id == null || id.isEmpty) {
        throw Exception("Project created but no _id returned");
      }
      return id;
    }

    throw Exception(
      "(${res.statusCode}) ${data["message"] ?? "Create project failed"}",
    );
  }

  /// GET /api/materials
  Future<List<dynamic>> getMaterials() async {
    final token = await _mustToken();
    final uri = Uri.parse(_join("/api/materials"));

    final res = await http
        .get(
          uri,
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
        )
        .timeout(const Duration(seconds: 30));

    final decoded = jsonDecode(res.body);

    if (res.statusCode == 200 && decoded is List) return decoded;

    if (decoded is Map && decoded["message"] != null) {
      throw Exception("(${res.statusCode}) ${decoded["message"]}");
    }

    throw Exception("(${res.statusCode}) Failed to load materials");
  }

  /// POST /api/projects/:id/estimate
  Future<Map<String, dynamic>> estimateProject({
    required String projectId,
    required List<Map<String, String>> selections,
  }) async {
    final token = await _mustToken();
    final uri = Uri.parse(_join("/api/projects/$projectId/estimate"));

    final res = await http
        .post(
          uri,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
          body: jsonEncode({"selections": selections}),
        )
        .timeout(const Duration(seconds: 60));

    final data = _safeJson(res.body);

    if (res.statusCode == 200) return data;

    throw Exception(
      "(${res.statusCode}) ${data["message"] ?? "Estimate failed"}",
    );
  }
}

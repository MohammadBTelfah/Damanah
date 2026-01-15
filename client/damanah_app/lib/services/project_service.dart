import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../services/session_service.dart';
import '../config/api_config.dart';

class ProjectService {
  // =========================
  // Helpers
  // =========================

  dynamic _safeDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return {"message": "Invalid server response", "raw": body};
    }
  }

  Map<String, dynamic> _safeJsonMap(String body) {
    final decoded = _safeDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {"message": "Invalid server response"};
  }

  String _errMsg(http.Response res) {
    final decoded = _safeDecode(res.body);

    if (decoded is Map && decoded["message"] != null) {
      return decoded["message"].toString();
    }

    return "Request failed (${res.statusCode})";
  }

  Future<String> _mustToken() async {
    final token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("No token. Please login again.");
    }
    return token;
  }

  Map<String, String> _authHeaders(String token, {bool json = false}) {
    return {
      if (json) "Content-Type": "application/json",
      "Authorization": "Bearer $token",
      "Accept": "application/json",
    };
  }

    // =========================
  // My Projects (client only)
  // =========================

  /// GET /api/projects/my
  Future<List<dynamic>> getMyProjects() async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/projects/my"));

    final res = await http
        .get(uri, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 30));

    final decoded = _safeDecode(res.body);

    if (res.statusCode == 200) {
      if (decoded is List) return decoded;

      if (decoded is Map && decoded["projects"] is List) {
        return List.from(decoded["projects"]);
      }

      throw Exception("Invalid my-projects response shape: ${res.body}");
    }

    throw Exception("(${res.statusCode}) ${_errMsg(res)}");
  }

  // =========================
// Project details
// =========================

/// GET /api/projects/:id
Future<Map<String, dynamic>> getProjectById(String projectId) async {
  final token = await _mustToken();
  final uri = Uri.parse(ApiConfig.join("/api/projects/$projectId"));

  final res = await http
      .get(uri, headers: _authHeaders(token))
      .timeout(const Duration(seconds: 30));

  final data = _safeJsonMap(res.body);

  if (res.statusCode == 200) return data;

  throw Exception("(${res.statusCode}) ${data["message"] ?? "Failed to load project"}");
}



  // =========================
  // Plan analyze
  // =========================

  /// POST /api/projects/plan/analyze (multipart planFile)
  Future<Map<String, dynamic>> analyzePlan({required String filePath}) async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/projects/plan/analyze"));

    final req = http.MultipartRequest("POST", uri);
    req.headers.addAll(_authHeaders(token));

    req.files.add(await http.MultipartFile.fromPath("planFile", filePath));

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);

    final map = _safeJsonMap(res.body);

    if (res.statusCode == 200) return map;

    final code = map["code"]?.toString();
    if (code == "AI_UNAVAILABLE") {
      throw Exception("AI_UNAVAILABLE");
    }

    throw Exception("(${res.statusCode}) ${map["message"] ?? "Analyze plan failed"}");
  }

  // =========================
  // Create project
  // =========================

  /// POST /api/projects
  Future<String> createProjectAndReturnId({
    required String title,
    String? description,
    String? location,
    required double area,
    required int floors,
    required String finishingLevel,
    required String buildingType,
    Map<String, dynamic>? planAnalysis,
  }) async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/projects"));

    final body = {
      "title": title,
      "description": description ?? "",
      "location": location ?? "",
      "area": area,
      "floors": floors,
      "finishingLevel": finishingLevel,
      "buildingType": buildingType,
      if (planAnalysis != null) "planAnalysis": planAnalysis,
    };

    final res = await http
        .post(
          uri,
          headers: _authHeaders(token, json: true),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));

    final data = _safeJsonMap(res.body);

    if (res.statusCode == 200 || res.statusCode == 201) {
      final project = data["project"];
      final id = (project is Map) ? project["_id"]?.toString() : null;
      if (id == null || id.isEmpty) {
        throw Exception("Project created but no _id returned");
      }
      return id;
    }

    throw Exception("(${res.statusCode}) ${data["message"] ?? "Create project failed"}");
  }

  // =========================
  // Materials
  // =========================

  /// GET /api/materials
  Future<List<dynamic>> getMaterials() async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/materials"));

    final res = await http
        .get(uri, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 30));

    final decoded = _safeDecode(res.body);

    if (res.statusCode == 200 && decoded is List) return decoded;

    if (decoded is Map && decoded["message"] != null) {
      throw Exception("(${res.statusCode}) ${decoded["message"]}");
    }

    throw Exception("(${res.statusCode}) Failed to load materials");
  }

  // =========================
  // Estimate
  // =========================

  /// POST /api/projects/:id/estimate
  Future<Map<String, dynamic>> estimateProject({
    required String projectId,
    required List<Map<String, String>> selections,
  }) async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/projects/$projectId/estimate"));

    final res = await http
        .post(
          uri,
          headers: _authHeaders(token, json: true),
          body: jsonEncode({"selections": selections}),
        )
        .timeout(const Duration(seconds: 60));

    final data = _safeJsonMap(res.body);

    if (res.statusCode == 200) return data;

    throw Exception("(${res.statusCode}) ${data["message"] ?? "Estimate failed"}");
  }

  // =========================
  // Save / Download
  // =========================

  /// PATCH /api/projects/:id/save
  Future<void> saveProject({required String projectId}) async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/projects/$projectId/save"));

    final res = await http
        .patch(uri, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200) return;

    throw Exception("(${res.statusCode}) ${_errMsg(res)}");
  }

  /// GET /api/projects/:id/estimate/download
  Future<String> downloadEstimateToFile({required String projectId}) async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/projects/$projectId/estimate/download"));

    final res = await http
        .get(uri, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 60));

    if (res.statusCode != 200) {
      throw Exception("(${res.statusCode}) ${_errMsg(res)}");
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/estimate_$projectId.json");
    await file.writeAsBytes(res.bodyBytes, flush: true);

    return file.path;
  }

  // =========================
  // Share / Assign
  // =========================

  /// POST /api/projects/:id/share  body { contractorId }
  Future<void> shareProject({
    required String projectId,
    required String contractorId,
  }) async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/projects/$projectId/share"));

    final res = await http
        .post(
          uri,
          headers: _authHeaders(token, json: true),
          body: jsonEncode({"contractorId": contractorId}),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200) return;

    throw Exception("(${res.statusCode}) ${_errMsg(res)}");
  }

  /// PATCH /api/projects/:id/assign  body { contractorId }
  Future<void> assignContractor({
    required String projectId,
    required String contractorId,
  }) async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/projects/$projectId/assign"));

    final res = await http
        .patch(
          uri,
          headers: _authHeaders(token, json: true),
          body: jsonEncode({"contractorId": contractorId}),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200) return;

    throw Exception("(${res.statusCode}) ${_errMsg(res)}");
  }

  // =========================
  // Contractors list (✅ endpoint الصحيح)
  // =========================

  /// GET /api/projects/contractors/available
  Future<List<dynamic>> getContractors() async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/projects/contractors/available"));

    final res = await http
        .get(uri, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 30));

    final decoded = _safeDecode(res.body);

    // ✅ Success: allow server to return List OR { contractors: [] }
    if (res.statusCode == 200) {
      if (decoded is List) return decoded;

      if (decoded is Map && decoded["contractors"] is List) {
        return List.from(decoded["contractors"]);
      }

      // ✅ 200 but wrong shape => show it
      throw Exception("Invalid contractors response shape: ${res.body}");
    }

    // ✅ Not success => show real reason (401/403/404...)
    throw Exception("(${res.statusCode}) ${_errMsg(res)}");
  }
}
// =========================
// My Projects (client only)
// =========================

/// GET /api/projects/my

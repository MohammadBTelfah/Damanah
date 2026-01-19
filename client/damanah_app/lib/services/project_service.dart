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
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
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
  // Project Actions (Client)
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

  // ✅ FIXED: Get Project By ID (supports different response shapes)
  /// GET /api/projects/:id
  Future<Map<String, dynamic>> getProjectById(String projectId) async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/projects/$projectId"));

    final res = await http
        .get(uri, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 30));

    final decoded = _safeDecode(res.body);

    if (res.statusCode == 200) {
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw Exception("Invalid project response shape: ${res.body}");
    }

    if (decoded is Map && decoded["message"] != null) {
      throw Exception("(${res.statusCode}) ${decoded["message"]}");
    }

    throw Exception("(${res.statusCode}) Failed to load project");
  }

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

    throw Exception(
        "(${res.statusCode}) ${data["message"] ?? "Create project failed"}");
  }

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

    throw Exception(
        "(${res.statusCode}) ${data["message"] ?? "Estimate failed"}");
  }

  /// POST /api/projects/plan/analyze
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
    if (code == "AI_UNAVAILABLE") throw Exception("AI_UNAVAILABLE");

    throw Exception(
        "(${res.statusCode}) ${map["message"] ?? "Analyze plan failed"}");
  }

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
  // Save / Download / Publish
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
    final uri =
        Uri.parse(ApiConfig.join("/api/projects/$projectId/estimate/download"));

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

  // 🔥 NEW: Publish Project
  Future<void> publishProject({required String projectId}) async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/projects/$projectId/publish"));

    final res = await http
        .patch(
          uri,
          headers: _authHeaders(token, json: true),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200) return;

    throw Exception("(${res.statusCode}) ${_errMsg(res)}");
  }

  // =========================
  // Contractor Utils (For Client)
  // =========================
  Future<List<dynamic>> getContractors() async {
    final token = await _mustToken();
    final uri =
        Uri.parse(ApiConfig.join("/api/projects/contractors/available"));

    final res = await http
        .get(uri, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 30));

    final decoded = _safeDecode(res.body);
    if (res.statusCode == 200) {
      if (decoded is List) return decoded;
      if (decoded is Map && decoded["contractors"] is List) {
        return List.from(decoded["contractors"]);
      }
      throw Exception("Invalid contractors response shape: ${res.body}");
    }
    throw Exception("(${res.statusCode}) ${_errMsg(res)}");
  }

  Future<void> assignContractor(
      {required String projectId, required String contractorId}) async {
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

  Future<void> shareProject(
      {required String projectId, required String contractorId}) async {
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

  // =========================
  // 🔥 ADDED: Contractor Specific Methods
  // =========================

  /// GET /api/projects/contractor/available
  /// GET /api/projects/contractor/available
  Future<List<dynamic>> getAvailableProjectsForContractor() async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/projects/contractor/available"));

    final res = await http
        .get(uri, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 30));

    final decoded = _safeDecode(res.body);

    if (res.statusCode == 200) {
      // ✅ التعديل هنا لضمان التعامل مع البيانات بشكل آمن
      if (decoded is Map && decoded["projects"] is List) {
        return List.from(decoded["projects"]);
      }
      if (decoded is List) {
        return decoded;
      }
      return [];
    }

    throw Exception("(${res.statusCode}) ${_errMsg(res)}");
  }

  /// POST /api/projects/:projectId/offers
  Future<void> createOffer({
    required String projectId,
    required double price,
    String? message,
  }) async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/projects/$projectId/offers"));

    final res = await http
        .post(
          uri,
          headers: _authHeaders(token, json: true),
          body: jsonEncode({
            "price": price,
            "message": (message ?? "").trim(),
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200 || res.statusCode == 201) return;

    throw Exception("(${res.statusCode}) ${_errMsg(res)}");
  }

  /// GET /api/projects/:projectId/offers  (Client only)
  Future<List<dynamic>> getProjectOffers({required String projectId}) async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/projects/$projectId/offers"));

    final res = await http
        .get(uri, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 30));

    final decoded = _safeDecode(res.body);

    if (res.statusCode == 200) {
      if (decoded is List) return decoded;
      return [];
    }

    throw Exception("(${res.statusCode}) ${_errMsg(res)}");
  }

  /// PATCH /api/projects/:projectId/offers/:offerId/accept  (Client only)
  Future<void> acceptOffer({
    required String projectId,
    required String offerId,
  }) async {
    final token = await _mustToken();
    final uri = Uri.parse(
      ApiConfig.join("/api/projects/$projectId/offers/$offerId/accept"),
    );

    final res = await http
        .patch(uri, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200) return;

    throw Exception("(${res.statusCode}) ${_errMsg(res)}");
  }

  // =========================
  // Tips & Community
  // =========================

  /// GET /api/tips
  Future<List<dynamic>> getTips() async {
    try {
      final token = await _mustToken();
      final uri = Uri.parse(ApiConfig.join("/api/tips"));

      final res = await http
          .get(uri, headers: _authHeaders(token))
          .timeout(const Duration(seconds: 20));

      final decoded = _safeDecode(res.body);

      if (res.statusCode == 200) {
        if (decoded is List) return decoded;
        return [];
      }
    } catch (e) {
      return [];
    }
    return [];
  }

  /// PATCH /api/projects/:id/status (Client/Contractor/Admin)
  Future<void> updateProjectStatus({
    required String projectId, // معطى مسمى
    required String newStatus, // معطى مسمى
  }) async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/projects/$projectId/status"));

    final res = await http
        .patch(
          uri,
          headers: _authHeaders(token, json: true),
          body: jsonEncode({"status": newStatus}),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200) return;

    throw Exception("(${res.statusCode}) ${_errMsg(res)}");
  }

  // =========================

  /// GET /api/projects/client/my-offers  (Client only)
  Future<List<dynamic>> getMyOffers() async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/projects/client/my-offers"));

    final res = await http
        .get(uri, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 30));

    final decoded = _safeDecode(res.body);

    if (res.statusCode == 200) {
      if (decoded is List) return decoded;
      return [];
    }

    throw Exception("(${res.statusCode}) ${_errMsg(res)}");
  }

  /// GET /api/projects/client/recent-offers
  Future<List<dynamic>> getRecentOffers() async {
    try {
      final token = await _mustToken();
      final uri = Uri.parse(ApiConfig.join("/api/projects/client/recent-offers"));

      final res = await http
          .get(uri, headers: _authHeaders(token))
          .timeout(const Duration(seconds: 20));

      final decoded = _safeDecode(res.body);

      if (res.statusCode == 200) {
        if (decoded is List) return decoded;
        return [];
      }
    } catch (e) {
      return [];
    }
    return [];
  }

  /// GET /api/projects/contractor/my
  Future<List<dynamic>> getMyProjectsForContractor() async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/projects/contractor/my"));

    final res = await http
        .get(uri, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 30));

    final decoded = _safeDecode(res.body);

    if (res.statusCode == 200) {
      if (decoded is Map && decoded["projects"] is List) {
        return List.from(decoded["projects"]);
      }
      if (decoded is List) return decoded;
      return [];
    }

    throw Exception("(${res.statusCode}) ${_errMsg(res)}");
  }

  // =========================
  // 🔥 NEW: Get client-related contractors only
  // GET /api/clients/my-contractors
  // Returns a list of contractors that are related to the logged-in client
  // (via Projects or Contracts). Safe parsing + profileImageUrl handling.
  Future<List<dynamic>> getMyContractors() async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/clients/my-contractors"));

    final res = await http
        .get(uri, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 30));

    final decoded = _safeDecode(res.body);

    if (res.statusCode == 200) {
      // If the API returns array directly
      if (decoded is List) {
        return decoded.map((e) {
          if (e is Map) {
            final m = Map<String, dynamic>.from(e);
            // ensure consistent profileImageUrl field if backend returns profileImage
            if ((m['profileImageUrl'] == null || m['profileImageUrl'] == '') &&
                (m['profileImage'] != null && m['profileImage'] is String)) {
              m['profileImageUrl'] = m['profileImage'];
            }
            return m;
          }
          return e;
        }).toList();
      }

      // If API returns object with list inside
      if (decoded is Map && (decoded['data'] is List || decoded['contractors'] is List)) {
        final list = decoded['data'] ?? decoded['contractors'];
        return (list as List).map((e) {
          if (e is Map) {
            final m = Map<String, dynamic>.from(e);
            if ((m['profileImageUrl'] == null || m['profileImageUrl'] == '') &&
                (m['profileImage'] != null && m['profileImage'] is String)) {
              m['profileImageUrl'] = m['profileImage'];
            }
            return m;
          }
          return e;
        }).toList();
      }

      // defensive: if returned object is a single contractor
      if (decoded is Map && decoded['_id'] != null) {
        final m = Map<String, dynamic>.from(decoded);
        if ((m['profileImageUrl'] == null || m['profileImageUrl'] == '') &&
            (m['profileImage'] != null && m['profileImage'] is String)) {
          m['profileImageUrl'] = m['profileImage'];
        }
        return [m];
      }

      // otherwise return empty list
      return [];
    }

    // unauthorized / other error
    if (res.statusCode == 401) {
      throw Exception("Unauthorized (${res.statusCode})");
    }

    throw Exception("(${res.statusCode}) ${_errMsg(res)}");
  }
}

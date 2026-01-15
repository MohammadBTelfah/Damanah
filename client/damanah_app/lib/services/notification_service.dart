import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/session_service.dart';
import '../config/api_config.dart';

class NotificationService {
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
    if (token == null || token.isEmpty) throw Exception("No token. Please login again.");
    return token;
  }

  Map<String, String> _authHeaders(String token, {bool json = false}) {
    return {
      if (json) "Content-Type": "application/json",
      "Authorization": "Bearer $token",
      "Accept": "application/json",
    };
  }

  /// GET /api/notifications
  Future<List<dynamic>> getMyNotifications() async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/notifications"));

    final res = await http.get(uri, headers: _authHeaders(token)).timeout(
      const Duration(seconds: 30),
    );

    final decoded = _safeDecode(res.body);

    if (res.statusCode == 200) {
      if (decoded is List) return decoded;
      if (decoded is Map && decoded["notifications"] is List) {
        return List.from(decoded["notifications"]);
      }
      throw Exception("Invalid notifications response shape: ${res.body}");
    }

    throw Exception("(${res.statusCode}) ${_errMsg(res)}");
  }

  /// GET /api/notifications/unread-count
  Future<int> getUnreadCount() async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/notifications/unread-count"));

    final res = await http.get(uri, headers: _authHeaders(token)).timeout(
      const Duration(seconds: 20),
    );

    final data = _safeJsonMap(res.body);

    if (res.statusCode == 200) {
      final c = data["count"];
      if (c is int) return c;
      return int.tryParse(c?.toString() ?? "0") ?? 0;
    }

    throw Exception("(${res.statusCode}) ${data["message"] ?? "Failed to load count"}");
  }

  /// PATCH /api/notifications/:id/read
  Future<void> markAsRead(String id) async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/notifications/$id/read"));

    final res = await http.patch(uri, headers: _authHeaders(token)).timeout(
      const Duration(seconds: 20),
    );

    if (res.statusCode == 200) return;
    throw Exception("(${res.statusCode}) ${_errMsg(res)}");
  }
}

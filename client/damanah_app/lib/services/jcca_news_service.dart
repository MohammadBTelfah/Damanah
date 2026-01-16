import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class JccaNewsService {
  dynamic _safeDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchNews({int limit = 5}) async {
    final uri = Uri.parse(ApiConfig.join("/api/public/jcca-news?limit=$limit"));

    final res = await http
        .get(uri, headers: const {"Accept": "application/json"})
        .timeout(const Duration(seconds: 20));

    // ✅ DEBUG (مهم جدًا لحل No news)
    // اطبعهم وشوف شو راجع من السيرفر
    // ignore: avoid_print
    print("NEWS status: ${res.statusCode}");
    // ignore: avoid_print
    print("NEWS body: ${res.body}");

    if (res.statusCode != 200) {
      throw Exception("Failed to load news (${res.statusCode})");
    }

    final decoded = _safeDecode(res.body);
    if (decoded is! Map) {
      throw Exception("Invalid news response");
    }

    final items = decoded["items"];
    if (items is! List) return [];

    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

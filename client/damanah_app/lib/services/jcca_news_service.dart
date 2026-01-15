import 'dart:convert';
import 'package:http/http.dart' as http;

// ✅ CORRECT IMPORT (ApiConfig is in lib/config/)
import '../config/api_config.dart';

class JccaNewsService {
  Future<List<Map<String, dynamic>>> fetchNews({int limit = 5}) async {
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}/api/public/jcca-news?limit=$limit",
    );

    final res = await http.get(uri);
    final decoded = jsonDecode(res.body);

    if (res.statusCode == 200) {
      final items = (decoded["items"] as List?) ?? [];
      return items
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    throw Exception("Failed to load news");
  }
}

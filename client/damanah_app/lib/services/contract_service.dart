import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'session_service.dart';

class ContractService {
  Future<String> _mustToken() async {
    final token = await SessionService.getToken();
    if (token == null) throw Exception("No token");
    return token;
  }

  Map<String, String> _headers(String token) => {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      };

  Future<List<dynamic>> getMyContracts() async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/contracts"));

    final res = await http.get(uri, headers: _headers(token));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List;
    }
    throw Exception("Failed to load contracts: ${res.body}");
  }
}
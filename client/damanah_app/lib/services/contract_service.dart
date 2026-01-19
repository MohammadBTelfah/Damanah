import 'dart:convert';
import 'dart:typed_data';
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
        "Content-Type": "application/json",
      };

  /// GET /api/contracts
  Future<List<dynamic>> getMyContracts() async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/contracts"));

    final res = await http.get(uri, headers: _headers(token));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);

      // يتعامل مع الحالتين: list مباشر أو {success,data}
      if (decoded is List) return decoded;
      if (decoded is Map && decoded["data"] is List) return decoded["data"] as List;

      throw Exception("Unexpected response shape: ${res.body}");
    }

    throw Exception("Failed to load contracts: ${res.body}");
  }

  /// POST /api/contracts
  /// يرجّع: { data: contract, pdfUrl: "/uploads/contracts/..." }
  Future<Map<String, dynamic>> createContract({
    required String projectId,
    required String clientId,
    required String contractorId,
    required num agreedPrice,
    int? durationMonths,
    String? paymentTerms,
    String? projectDescription,
    List<String>? materialsAndServices,
    String? terms,
    String? startDate, // "YYYY-MM-DD"
    String? endDate,   // "YYYY-MM-DD"
  }) async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/contracts"));

    final body = <String, dynamic>{
      "project": projectId,
      "client": clientId,
      "contractor": contractorId,
      "agreedPrice": agreedPrice,
      if (durationMonths != null) "durationMonths": durationMonths,
      if (paymentTerms != null) "paymentTerms": paymentTerms,
      if (projectDescription != null) "projectDescription": projectDescription,
      if (materialsAndServices != null) "materialsAndServices": materialsAndServices,
      if (terms != null) "terms": terms,
      if (startDate != null) "startDate": startDate,
      if (endDate != null) "endDate": endDate,
    };

    final res = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode(body),
    );

    if (res.statusCode == 201 || res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception("Unexpected response shape: ${res.body}");
    }

    throw Exception("Failed to create contract: ${res.body}");
  }

  /// خيار 1: إذا pdfUrl عام (static /uploads) تقدر تجيب bytes بدون توكن
  /// خيار 2: إذا بدك endpoint محمي: GET /api/contracts/:id/pdf (مع توكن)
  Future<Uint8List> fetchContractPdfBytesById(String contractId) async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/contracts/$contractId/pdf"));

    final res = await http.get(uri, headers: {
      "Authorization": "Bearer $token",
      "Accept": "application/pdf",
    });

    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    throw Exception("Failed to fetch pdf: ${res.statusCode} ${res.body}");
  }

  /// إذا عندك pdfUrl مثل: "/uploads/contracts/contract-xxx.pdf"
  /// وبدك تجيب bytes مباشرة
  Future<Uint8List> fetchPdfBytesFromUrl(String pdfUrl) async {
    final uri = Uri.parse(ApiConfig.join(pdfUrl));
    final res = await http.get(uri);

    if (res.statusCode == 200) return res.bodyBytes;
    throw Exception("Failed to fetch pdf from url: ${res.statusCode}");
  }
}

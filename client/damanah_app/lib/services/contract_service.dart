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

      if (decoded is List) return decoded;
      if (decoded is Map && decoded["data"] is List) return decoded["data"] as List;

      throw Exception("Unexpected response shape: ${res.body}");
    }

    throw Exception("Failed to load contracts: ${res.body}");
  }

  /// POST /api/contracts
  /// ✅ التعديل: السيرفر الآن يرجع رابط Cloudinary كامل في pdfUrl
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
    String? startDate, 
    String? endDate,   
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

  /// ✅ التعديل الأهم: جلب الـ PDF من Cloudinary
  /// بما أن الرابط أصبح يبدأ بـ https://res.cloudinary.com فلا نحتاج لدمجه مع ApiConfig
  Future<Uint8List> fetchPdfBytesFromUrl(String pdfUrl) async {
    // نتحقق إذا كان الرابط يبدأ بـ http (رابط Cloudinary كامل) أو مسار محلي قديم
    final finalUrl = pdfUrl.startsWith('http') 
        ? pdfUrl 
        : ApiConfig.join(pdfUrl);
        
    final uri = Uri.parse(finalUrl);
    
    // Cloudinary لا يتطلب Authorization header لجلب الملفات العامة
    final res = await http.get(uri);

    if (res.statusCode == 200) return res.bodyBytes;
    throw Exception("Failed to fetch pdf from url: ${res.statusCode}");
  }

  /// دالة جلب الـ PDF بواسطة الـ ID (إذا كنت تستخدم Endpoint خاص في الباك إند)
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
}
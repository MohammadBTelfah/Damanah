import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'session_service.dart';

class ContractService {
  
  // =========================
  // Helpers
  // =========================

  Future<String> _mustToken() async {
    final token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("No token found. Please login.");
    }
    return token;
  }

  /// الهيدر الموحد: يضمن إرسال واستقبال JSON
  Map<String, String> _headers(String token) => {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
        "Content-Type": "application/json",
      };

  // =========================
  // Methods
  // =========================

  /// GET /api/contracts
  /// جلب عقود المستخدم (سواء كان عميل أو مقاول)
  Future<List<dynamic>> getMyContracts() async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/contracts"));

    final res = await http.get(uri, headers: _headers(token));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);

      // ✅ التعامل مع أشكال الاستجابة المختلفة من السيرفر
      if (decoded is List) return decoded;
      if (decoded is Map && decoded["data"] is List) return decoded["data"] as List;
      if (decoded is Map && decoded["contracts"] is List) return decoded["contracts"] as List;
      
      // في حال كانت القائمة فارغة أو الشكل غير معروف
      return []; 
    }

    throw Exception("Failed to load contracts: ${res.statusCode} ${res.body}");
  }

  /// POST /api/contracts
  /// إنشاء عقد جديد (للمقاول)
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

    // بناء الجسم (Body) مع تجاهل القيم الفارغة (null)
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
      headers: _headers(token), // ✅ تأكدنا أن الهيدر يحتوي application/json
      body: jsonEncode(body),
    );

    if (res.statusCode == 201 || res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      
      // نتوقع أن يرجع السيرفر كائن يحتوي على success, data, pdfUrl
      if (decoded is Map<String, dynamic>) return decoded;
      
      throw Exception("Unexpected response shape: ${res.body}");
    }

    // استخراج رسالة الخطأ من السيرفر إن وجدت
    String errorMsg = "Failed to create contract";
    try {
      final errDecoded = jsonDecode(res.body);
      if (errDecoded is Map && errDecoded["message"] != null) {
        errorMsg = errDecoded["message"];
      }
    } catch (_) {}

    throw Exception("$errorMsg (${res.statusCode})");
  }

  /// ✅ جلب ملف الـ PDF كـ Bytes
  /// تدعم الروابط المباشرة (Cloudinary) أو الروابط النسبية (Local)
  Future<Uint8List> fetchPdfBytesFromUrl(String pdfUrl) async {
    // 1. تحديد الرابط الصحيح (إذا كان يبدأ بـ http فهو خارجي، وإلا فهو من السيرفر المحلي)
    final finalUrl = pdfUrl.startsWith('http') ? pdfUrl : ApiConfig.join(pdfUrl);
    final uri = Uri.parse(finalUrl);

    // 2. إذا كان الرابط خارجي (Cloudinary Public)، غالباً لا نحتاج Header
    // لكن إذا كان محلي، قد نحتاج Token. هنا سنفترض أنه Public Access كما حددنا في Backend
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    
    throw Exception("Failed to fetch PDF from URL: ${res.statusCode}");
  }

  /// دالة احتياطية: جلب الـ PDF عن طريق الـ ID (Endpoint محمي)
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
    
    throw Exception("Failed to fetch PDF by ID: ${res.statusCode}");
  }
}
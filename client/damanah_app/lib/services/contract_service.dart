import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'session_service.dart';

class ContractService {
  
  // =========================
  // Helpers (دوال مساعدة)
  // =========================

  /// جلب التوكن والتأكد من وجوده
  Future<String> _mustToken() async {
    final token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("No token found. Please login.");
    }
    return token;
  }

  /// الهيدر الموحد لجميع الطلبات
  Map<String, String> _headers(String token) => {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
        "Content-Type": "application/json",
      };

  // =========================
  // Methods (العمليات الأساسية)
  // =========================

  /// جلب عقود المستخدم (سواء كان عميل أو مقاول)
  Future<List<dynamic>> getMyContracts() async {
    final token = await _mustToken();
    final uri = Uri.parse(ApiConfig.join("/api/contracts"));

    final res = await http.get(uri, headers: _headers(token));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);

      if (decoded is List) return decoded;
      if (decoded is Map && decoded["data"] is List) return decoded["data"] as List;
      if (decoded is Map && decoded["contracts"] is List) return decoded["contracts"] as List;
      
      return []; 
    }

    throw Exception("Failed to load contracts: ${res.statusCode}");
  }

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

    try {
      // ✅ زيادة مهلة الانتظار لـ 90 ثانية لمنع الـ Timeout أثناء توليد الـ PDF
      final res = await http.post(
        uri,
        headers: _headers(token), 
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 90)); 

      if (res.statusCode == 201 || res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        
        // الرد يحتوي على النجاح، العقد، ورابط الـ PDF المحدث بالبيانات الرسمية
        if (decoded is Map<String, dynamic>) return decoded;
        
        throw Exception("Unexpected response shape: ${res.body}");
      }

      String errorMsg = "Failed to create contract";
      try {
        final errDecoded = jsonDecode(res.body);
        if (errDecoded is Map && errDecoded["message"] != null) {
          errorMsg = errDecoded["message"];
        }
      } catch (_) {}

      throw Exception("$errorMsg (${res.statusCode})");

    } on TimeoutException catch (_) {
      throw Exception("انتهت مهلة الاتصال: السيرفر يستغرق وقتاً طويلاً في إنشاء العقد، يرجى المحاولة لاحقاً.");
    } catch (e) {
      throw Exception("حدث خطأ غير متوقع: ${e.toString()}");
    }
  }

  /// ✅ جلب ملف الـ PDF كـ Bytes من رابط Cloudinary
  Future<Uint8List> fetchPdfBytesFromUrl(String pdfUrl) async {
    final finalUrl = pdfUrl.startsWith('http') ? pdfUrl : ApiConfig.join(pdfUrl);
    final uri = Uri.parse(finalUrl);

    // التحميل من Cloudinary كـ Public Access
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    
    throw Exception("Failed to fetch PDF from URL: ${res.statusCode}");
  }

  /// جلب الـ PDF عن طريق الـ ID (في حال كان الرابط غير متاح)
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
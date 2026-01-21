import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ✅ التعديل 1: حذفنا confidence لأنه لم يعد مطلوباً في الـ API
class ScanIdResult {
  final File imageFile;
  final String nationalId;
  final String fullName; // ✅ الاسم الإنجليزي

  ScanIdResult({
    required this.imageFile,
    required this.nationalId,
    required this.fullName,
  });
}

class ScanIdScreen extends StatefulWidget {
  const ScanIdScreen({super.key});

  @override
  State<ScanIdScreen> createState() => _ScanIdScreenState();
}

class _ScanIdScreenState extends State<ScanIdScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _fullNameCtrl = TextEditingController();
  final TextEditingController _nationalIdCtrl = TextEditingController();

  File? _image;
  bool _loading = false;

  /// ✅ استخراج الرقم الوطني الأردني
  String? _extractJordanNationalId(String text) {
    // يبحث عن أي رقم يبدأ بـ 1 أو 2 ويتكون من 10 خانات
    final regex = RegExp(r'\b[12]\d{9}\b');
    final match = regex.firstMatch(text);
    return match?.group(0);
  }

  Future<void> _pickAndScan() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90, // جودة جيدة للـ OCR
      );

      if (xfile == null) return;

      setState(() {
        _loading = true;
        _image = File(xfile.path);
        // _rawText = "";
        _nationalIdCtrl.clear();
      });

      final inputImage = InputImage.fromFile(_image!);

      // استخدام Script Latin كافٍ للأرقام الإنجليزية المستخدمة في الهوية
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );

      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final text = recognizedText.text;
      final extracted = _extractJordanNationalId(text);

      setState(() {
        // _rawText = text;
        if (extracted != null) {
          _nationalIdCtrl.text = extracted;
        }
        _loading = false;
      });

      if (extracted == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Could not detect ID automatically. Please enter it manually.",
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Scan failed: $e")));
    }
  }

  void _confirm() {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please scan your ID first")),
      );
      return;
    }

    final nid = _nationalIdCtrl.text.trim();
    final fullName = _fullNameCtrl.text.trim();

    // ✅ التحقق من الطول (10 أرقام)
    if (!RegExp(r'^[0-9]{10}$').hasMatch(nid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("National ID must be exactly 10 digits")),
      );
      return;
    }
    // ✅ التحقق من الاسم الكامل
    if (fullName.isEmpty || fullName.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your full name (English)")),
      );
      return;
    }

    // ✅ إرجاع النتيجة (الصورة + الرقم)
    Navigator.pop(
      context,
      ScanIdResult(
        imageFile: _image!,
        nationalId: nid,
        fullName: _fullNameCtrl.text.trim(), // ✅ الاسم الإنجليزي
      ),
    );
  }

  @override
  void dispose() {
    _nationalIdCtrl.dispose();
    _fullNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Identity Document")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          // إضافة Scroll لتجنب overflow
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // زر الالتقاط
              ElevatedButton.icon(
                onPressed: _loading ? null : _pickAndScan,
                icon: const Icon(Icons.camera_alt),
                label: Text(_image == null ? "Take Photo" : "Retake Photo"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),

              const SizedBox(height: 12),

              if (_loading) const LinearProgressIndicator(),

              const SizedBox(height: 12),

              // عرض الصورة الملتقطة
              if (_image != null)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_image!, fit: BoxFit.cover),
                  ),
                )
              else
                Container(
                  height: 200,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: const Text(
                    "No image captured",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),

              const SizedBox(height: 20),

              // حقل الاسم الإنجليزي
              const SizedBox(height: 20),

              // ===== Full Name (Editable) =====
              TextField(
                controller: _fullNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: "Full Name (English)",
                  hintText: "e.g. MOHAMMAD BASAM TELFAH",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),

              // حقل الرقم الوطني
              TextField(
                controller: _nationalIdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "National ID Number",
                  hintText: "Scanned number (editable)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),

              const SizedBox(height: 20),

              // زر التأكيد
              ElevatedButton(
                onPressed: _loading ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // لون مميز للتأكيد
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  "Confirm & Use This ID",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

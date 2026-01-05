import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ScanIdResult {
  final File imageFile;
  final String nationalId;
  final double? confidence; // حالياً null (ML Kit text_recognition ما يعطي confidence بسهولة)

  ScanIdResult({
    required this.imageFile,
    required this.nationalId,
    this.confidence,
  });
}

class ScanIdScreen extends StatefulWidget {
  const ScanIdScreen({super.key});

  @override
  State<ScanIdScreen> createState() => _ScanIdScreenState();
}

class _ScanIdScreenState extends State<ScanIdScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nationalIdCtrl = TextEditingController();

  File? _image;
  bool _loading = false;
  String _rawText = "";

  /// ✅ استخراج الرقم الوطني الأردني:
  /// - 10 أرقام
  /// - يبدأ عادةً بـ 1 أو 2
  String? _extractJordanNationalId(String text) {
    // خلي النص كما هو (بدون حذف أرقام مهمة)، بس بدنا نلتقط 10 أرقام متتالية
    // pattern: يبدأ بـ 1 أو 2 ثم 9 أرقام = 10 أرقام
    final regex = RegExp(r'\b[12]\d{9}\b');
    final match = regex.firstMatch(text);
    return match?.group(0);
  }

  Future<void> _pickAndScan() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (xfile == null) return;

      setState(() {
        _loading = true;
        _image = File(xfile.path);
        _rawText = "";
        _nationalIdCtrl.clear();
      });

      final inputImage = InputImage.fromFile(_image!);

      // ✅ عربي + إنجليزي؟ (الهوية الأردنية غالباً EN بالأرقام + نص عربي/إنجليزي)
      // latin مناسب للأرقام والانجليزي
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final text = recognizedText.text;

      // ✅ استخراج الرقم الوطني
      final extracted = _extractJordanNationalId(text);

      setState(() {
        _rawText = text;
        if (extracted != null) {
          _nationalIdCtrl.text = extracted;
        }
        _loading = false;
      });

      // إذا ما لقاه، أعطي تنبيه خفيف
      if (extracted == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("لم يتم اكتشاف الرقم الوطني تلقائياً، اكتبُه يدوياً.")),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Scan failed: $e")),
      );
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

    // ✅ تحقق بسيط: 10 أرقام
    if (!RegExp(r'^[0-9]{10}$').hasMatch(nid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("National ID must be 10 digits")),
      );
      return;
    }

    Navigator.pop(
      context,
      ScanIdResult(
        imageFile: _image!,
        nationalId: nid,
        confidence: null,
      ),
    );
  }

  @override
  void dispose() {
    _nationalIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan ID")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _loading ? null : _pickAndScan,
              icon: const Icon(Icons.camera_alt),
              label: const Text("Scan your ID"),
            ),
            const SizedBox(height: 12),

            if (_loading) const LinearProgressIndicator(),

            const SizedBox(height: 12),
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_image!, height: 180, fit: BoxFit.cover),
              ),

            const SizedBox(height: 12),
            TextField(
              controller: _nationalIdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "National ID",
                hintText: "Auto-filled if detected (editable)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _confirm,
              child: const Text("Confirm"),
            ),

            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _rawText.isEmpty ? "OCR text will appear here..." : _rawText,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

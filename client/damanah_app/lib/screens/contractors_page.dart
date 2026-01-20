import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ مهم للـ Clipboard
import '../services/project_service.dart';
import '../config/api_config.dart'; // ✅ استيراد ملف الإعدادات
import 'contractor_details_page.dart';

class ContractorsPage extends StatefulWidget {
  const ContractorsPage({super.key});

  @override
  State<ContractorsPage> createState() => _ContractorsPageState();
}

class _ContractorsPageState extends State<ContractorsPage> {
  final _service = ProjectService();

  bool _loading = true;
  String? _error;
  List<dynamic> _contractors = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// ✅ تم تعديل هذه الدالة لتجلب فقط المقاولين الخاصين بك
  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // نطلب فقط المقاولين المربوطين بمشاريعي
      final list = await _service.getMyContractors();
      
      if (mounted) {
        setState(() => _contractors = list);
      }
    } catch (e) {
      final msg = e.toString();
      // ✅ إذا كان السيرفر يعيد 404 فهذا يعني "لا يوجد مقاولين مربوطين حالياً"
      // نعتبرها حالة قائمة فارغة وليست خطأ أحمر
      if (msg.contains('404')) {
        if (mounted) setState(() => _contractors = []);
      } else {
        if (mounted) setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ====================== Smart URL helpers (Cloudinary support) ======================

  /// ✅ دالة ذكية لمعالجة روابط الصور (Cloudinary أو Render)
  String _toAbsoluteUrl(String maybeUrlOrPath) {
    final v = maybeUrlOrPath.trim();
    if (v.isEmpty) return "";

    // إذا كان الرابط كاملاً من Cloudinary (يبدأ بـ http) نرجعه فوراً
    if (v.startsWith("http://") || v.startsWith("https://")) return v;

    // إذا كان مساراً قديماً على السيرفر، نقوم بدمجه مع الرابط الأساسي من ApiConfig
    return ApiConfig.join(v);
  }

  // ====================== UI ======================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1814),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Contractors",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF9EE7B7)))
            : _error != null
                ? _errorView()
                : _contractors.isEmpty
                    ? _emptyView()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        itemCount: _contractors.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: Colors.white.withOpacity(0.06)),
                        itemBuilder: (context, i) {
                          final c = (_contractors[i] is Map)
                              ? Map<String, dynamic>.from(_contractors[i])
                              : <String, dynamic>{};

                          return _contractorCard(c);
                        },
                      ),
      ),
    );
  }

  // ===================== Contractor Card =====================

  Widget _contractorCard(Map<String, dynamic> c) {
    final name = c["name"]?.toString() ?? "Contractor";
    final phone = c["phone"]?.toString() ?? "-";
    final city = c["city"]?.toString() ?? c["location"]?.toString() ?? "";
    final specialty =
        c["specialty"]?.toString() ?? c["type"]?.toString() ?? "General";
    final available = c["available"] == true || (c["isActive"] == true);

    // ✅ معالجة الرابط عبر الدالة الذكية لضمان عرض صور Cloudinary
    final imgRaw = (c["profileImageUrl"] ?? c["profileImage"] ?? "").toString();
    final img = _toAbsoluteUrl(imgRaw);

    void openDetails() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ContractorDetailsPage(contractor: c)),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: openDetails,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F261F).withOpacity(0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: img.isNotEmpty
                  ? Image.network(
                      img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, color: Colors.white70),
                    )
                  : const Icon(Icons.person, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [if (city.isNotEmpty) city, specialty].join(" • "),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _chip(
                        available ? "available" : "busy",
                        available ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                phone,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () async {
                                if (phone.trim().isEmpty || phone == "-") return;
                                await Clipboard.setData(
                                  ClipboardData(text: phone),
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Copied"),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.copy_rounded,
                                  size: 16,
                                  color: Colors.white.withOpacity(0.75),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: openDetails,
              icon: const Icon(Icons.chevron_right, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== Helpers =====================

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _errorView() {
    return ListView(
      children: [
        const SizedBox(height: 70),
        Icon(
          Icons.error_outline,
          size: 48,
          color: Colors.white.withOpacity(0.7),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _error ?? "Unknown error",
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 18),
          child: ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9EE7B7), foregroundColor: Colors.black),
            child: const Text("Retry"),
          ),
        ),
      ],
    );
  }

  Widget _emptyView() {
    return ListView(
      children: const [
        SizedBox(height: 100),
        Icon(Icons.person_search_outlined, size: 64, color: Colors.white24),
        SizedBox(height: 16),
        Center(
          child: Text(
            "No contractors linked to your projects yet",
            style: TextStyle(color: Colors.white60, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
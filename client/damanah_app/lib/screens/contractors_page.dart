import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/project_service.dart';
import '../config/api_config.dart';
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

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _service.getMyContractors();
      
      // ✅ أداة تشخيص: اطبع البيانات في الـ Debug Console
      debugPrint("البيانات الواصلة من السيرفس: $list");

      if (mounted) {
        setState(() {
          _contractors = list;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("خطأ في جلب المقاولين: $e");
      if (mounted) {
        setState(() {
          if (e.toString().contains('404')) {
            _contractors = [];
          } else {
            _error = e.toString();
          }
          _loading = false;
        });
      }
    }
  }

  String _toAbsoluteUrl(String? maybeUrlOrPath) {
    if (maybeUrlOrPath == null || maybeUrlOrPath.trim().isEmpty) return "";
    final v = maybeUrlOrPath.trim();
    if (v.startsWith("http")) return v;
    return ApiConfig.join(v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1814),
        elevation: 0,
        title: const Text("My Contractors", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _contractors.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final c = _contractors[i];
                          final data = (c is Map) ? Map<String, dynamic>.from(c) : <String, dynamic>{};
                          return _contractorCard(data);
                        },
                      ),
      ),
    );
  }

  Widget _contractorCard(Map<String, dynamic> c) {
    final name = c["name"]?.toString() ?? "Unknown";
    final phone = c["phone"]?.toString() ?? "-";
    final imgUrl = _toAbsoluteUrl(c["profileImageUrl"] ?? c["profileImage"]);

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContractorDetailsPage(contractor: c))),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF1B3A35).withOpacity(0.5),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.white10,
              backgroundImage: imgUrl.isNotEmpty ? NetworkImage(imgUrl) : null,
              child: imgUrl.isEmpty ? const Icon(Icons.person, color: Colors.white70) : null,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 5),
                  Text(phone, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _emptyView() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        const Icon(Icons.person_search, size: 60, color: Colors.white10),
        const SizedBox(height: 15),
        const Center(child: Text("No contractors linked yet", style: TextStyle(color: Colors.white38))),
        const SizedBox(height: 10),
        TextButton(onPressed: _load, child: const Text("Refresh", style: TextStyle(color: Color(0xFF9EE7B7)))),
      ],
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_error ?? "Error", style: const TextStyle(color: Colors.redAccent)),
          ElevatedButton(onPressed: _load, child: const Text("Retry")),
        ],
      ),
    );
  }
}
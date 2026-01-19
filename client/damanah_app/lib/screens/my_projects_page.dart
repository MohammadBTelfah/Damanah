import 'package:flutter/material.dart';
import '../services/project_service.dart';
import '../screens/project_details_page.dart';

class MyProjectsPage extends StatefulWidget {
  const MyProjectsPage({super.key});

  @override
  State<MyProjectsPage> createState() => _MyProjectsPageState();
}

class _MyProjectsPageState extends State<MyProjectsPage> {
  final _service = ProjectService();

  bool _loading = true;
  String? _error;
  List<dynamic> _projects = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _service.getMyProjects();
      
      // ✅ التعديل الأول: فلترة القائمة لإخفاء الـ draft
      final filteredList = list.where((element) {
        final p = (element is Map) ? element : <String, dynamic>{};
        final status = p["status"]?.toString().toLowerCase() ?? "";
        return status != "draft"; // استبعاد المسودات
      }).toList();

      setState(() => _projects = filteredList);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDetails(Map<String, dynamic> p) {
    final id = (p["_id"] ?? p["id"] ?? p["projectId"] ?? "").toString();

    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Project id is missing")),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectDetailsPage(projectId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1814),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "My Projects",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF9EE7B7),
        backgroundColor: const Color(0xFF1A2C24),
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF9EE7B7)))
            : _error != null
                ? _buildErrorView()
                : _projects.isEmpty
                    ? _buildEmptyView()
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _projects.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, i) {
                          final p = (_projects[i] is Map)
                              ? Map<String, dynamic>.from(_projects[i])
                              : <String, dynamic>{};
                          return _buildProjectCard(p);
                        },
                      ),
      ),
    );
  }

  // ✅ تصميم الكرت الجديد
  Widget _buildProjectCard(Map<String, dynamic> p) {
    final title = p["title"]?.toString() ?? "Untitled Project";
    final location = p["location"]?.toString() ?? "No location";
    final status = p["status"]?.toString() ?? "open";
    final area = p["area"]?.toString() ?? "0";
    final floors = p["floors"]?.toString() ?? "1";

    return InkWell(
      onTap: () => _openDetails(p),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF15221D), // لون خلفية أفتح قليلاً من الشاشة
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Icon + Title + Arrow
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9EE7B7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.maps_home_work_rounded, color: Color(0xFF9EE7B7), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: Colors.white54, size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
              ],
            ),
            
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.05), height: 1),
            const SizedBox(height: 16),

            // Footer: Stats & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Info Items
                Row(
                  children: [
                    _infoBadge(Icons.square_foot_rounded, "$area m²"),
                    const SizedBox(width: 12),
                    _infoBadge(Icons.layers_outlined, "$floors Flr"),
                  ],
                ),
                // Status Chip
                _statusChip(status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final s = status.toLowerCase().trim();
    String text = s.replaceAll("_", " ");
    
    Color bg;
    Color fg;

    switch (s) {
      case "open":
        bg = const Color(0xFF2E7D32).withOpacity(0.2); // Greenish
        fg = const Color(0xFF81C784);
        text = "Open";
        break;
      case "in_progress":
        bg = const Color(0xFFEF6C00).withOpacity(0.2); // Orangish
        fg = const Color(0xFFFFCC80);
        text = "In Progress";
        break;
      case "completed":
        bg = const Color(0xFF1565C0).withOpacity(0.2); // Blueish
        fg = const Color(0xFF64B5F6);
        text = "Completed";
        break;
      default:
        bg = Colors.white.withOpacity(0.1);
        fg = Colors.white70;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.folder_off_outlined, size: 40, color: Colors.white38),
          ),
          const SizedBox(height: 16),
          const Text(
            "No active projects",
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            "Create a new project to get started",
            style: TextStyle(color: Colors.white30, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              "Oops!",
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9EE7B7),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("Try Again", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
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
      setState(() => _projects = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDetails(Map<String, dynamic> p) {
    final id = (p["_id"] ?? p["id"] ?? p["projectId"] ?? "").toString();

    debugPrint("OPEN DETAILS => id=$id title=${p["title"]}");

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
        title: const Text(
          "My Projects",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 60),
                      Icon(Icons.error_outline,
                          size: 46, color: Colors.white.withOpacity(0.7)),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ElevatedButton(
                          onPressed: _load,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9EE7B7),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text("Retry"),
                        ),
                      )
                    ],
                  )
                : _projects.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 70),
                          Icon(Icons.folder_open,
                              size: 52, color: Colors.white38),
                          SizedBox(height: 12),
                          Center(
                            child: Text(
                              "No projects yet",
                              style: TextStyle(color: Colors.white60),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        itemCount: _projects.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: Colors.white.withOpacity(0.06)),
                        itemBuilder: (context, i) {
                          final p = (_projects[i] is Map)
                              ? Map<String, dynamic>.from(_projects[i])
                              : <String, dynamic>{};

                          final title = p["title"]?.toString() ?? "Project";
                          final location = p["location"]?.toString() ?? "";
                          final status = p["status"]?.toString() ?? "open";
                          final area = p["area"]?.toString() ?? "";
                          final floors = p["floors"]?.toString() ?? "";

                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _openDetails(p),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF0F261F).withOpacity(0.6),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.06)),
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
                                    child: const Icon(
                                      Icons.home_work_outlined,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
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
                                          [
                                            if (location.isNotEmpty) location,
                                            if (area.isNotEmpty) "Area: $area",
                                            if (floors.isNotEmpty)
                                              "Floors: $floors",
                                          ].join(" • "),
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        _statusChip(status),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  IconButton(
                                    onPressed: () => _openDetails(p),
                                    icon: const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final s = status.toLowerCase().trim();
    final text = s.replaceAll("_", " ");
    final isOpen = s == "open";
    final isProgress = s == "in_progress";

    final bg = isOpen
        ? Colors.green.withOpacity(0.18)
        : isProgress
            ? Colors.orange.withOpacity(0.18)
            : Colors.white.withOpacity(0.10);

    final fg = isOpen
        ? Colors.greenAccent
        : isProgress
            ? Colors.orangeAccent
            : Colors.white70;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

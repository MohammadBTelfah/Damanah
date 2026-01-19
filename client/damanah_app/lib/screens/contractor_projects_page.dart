import 'package:flutter/material.dart';

import '../services/project_service.dart';
import '../services/session_service.dart';
import 'contractor_project_details_page.dart';

class ContractorProjectsPage extends StatefulWidget {
  const ContractorProjectsPage({super.key});

  @override
  State<ContractorProjectsPage> createState() => _ContractorProjectsPageState();
}

class _ContractorProjectsPageState extends State<ContractorProjectsPage> {
  final ProjectService _service = ProjectService();

  String? _contractorId;

  Future<List<dynamic>>? _myFuture;
  Future<List<dynamic>>? _availableFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await SessionService.getUser();
    _contractorId = (u?["_id"] ?? u?["id"] ?? "").toString();

    setState(() {
      _myFuture = _service.getMyProjectsForContractor();
      _availableFuture = _service.getAvailableProjectsForContractor();
    });
  }

  void _openProject(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContractorProjectDetailsPage(projectId: id),
      ),
    );
  }

  bool _hasMyOffer(Map<String, dynamic> project) {
    final cid = (_contractorId ?? "").trim();
    if (cid.isEmpty) return false;

    final offers = project["offers"];
    if (offers is! List) return false;

    for (final o in offers) {
      if (o is Map) {
        final c = o["contractor"];
        if (c is String && c == cid) return true;
        if (c is Map && (c["_id"]?.toString() == cid)) return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0E1814);
    const card = Color(0xFF1B3A35);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text("Projects",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.white70,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: Color(0xFF9EE7B7),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      tabs: [
                        Tab(text: "My Projects"),
                        Tab(text: "Applied"),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 620,
                      child: TabBarView(
                        children: [
                          _ProjectsList(
                            future: _myFuture,
                            emptyText: "No assigned projects yet.",
                            cardColor: card,
                            onOpen: _openProject,
                          ),
                          _AppliedList(
                            future: _availableFuture,
                            emptyText: "No applied offers yet.",
                            cardColor: card,
                            hasMyOffer: _hasMyOffer,
                            onOpen: _openProject,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectsList extends StatelessWidget {
  final Future<List<dynamic>>? future;
  final String emptyText;
  final Color cardColor;
  final void Function(String id) onOpen;

  const _ProjectsList({
    required this.future,
    required this.emptyText,
    required this.cardColor,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return const Center(
        child: Text("Loading...", style: TextStyle(color: Colors.white70)),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text("Error: ${snap.error}",
                style: const TextStyle(color: Colors.redAccent)),
          );
        }

        final items = snap.data ?? [];
        if (items.isEmpty) {
          return Center(
            child:
                Text(emptyText, style: const TextStyle(color: Colors.white70)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(10),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final p = (items[i] as Map).cast<String, dynamic>();
            final id = (p["_id"] ?? p["id"] ?? "").toString();
            final title = (p["title"] ?? p["name"] ?? "Project").toString();
            final location = (p["location"] ?? "").toString();
            final status = (p["status"] ?? "").toString();

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  if (location.isNotEmpty)
                    Text(location,
                        style: const TextStyle(color: Colors.white70)),
                  if (status.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text("Status: $status",
                        style: const TextStyle(color: Colors.white60)),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        if (id.isEmpty) return;
                        onOpen(id);
                      },
                      child: const Text("View details"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AppliedList extends StatelessWidget {
  final Future<List<dynamic>>? future;
  final String emptyText;
  final Color cardColor;
  final bool Function(Map<String, dynamic> project) hasMyOffer;
  final void Function(String id) onOpen;

  const _AppliedList({
    required this.future,
    required this.emptyText,
    required this.cardColor,
    required this.hasMyOffer,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return const Center(
        child: Text("Loading...", style: TextStyle(color: Colors.white70)),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text("Error: ${snap.error}",
                style: const TextStyle(color: Colors.redAccent)),
          );
        }

        final raw = snap.data ?? [];
        final items = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where(hasMyOffer)
            .toList();

        if (items.isEmpty) {
          return Center(
            child:
                Text(emptyText, style: const TextStyle(color: Colors.white70)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(10),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final p = items[i];
            final id = (p["_id"] ?? p["id"] ?? "").toString();
            final title = (p["title"] ?? p["name"] ?? "Project").toString();
            final location = (p["location"] ?? "").toString();
            final status = (p["status"] ?? "").toString();

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  if (location.isNotEmpty)
                    Text(location,
                        style: const TextStyle(color: Colors.white70)),
                  if (status.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text("Status: $status",
                        style: const TextStyle(color: Colors.white60)),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        if (id.isEmpty) return;
                        onOpen(id);
                      },
                      child: const Text("View details"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

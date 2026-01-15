import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../services/project_service.dart';
import 'app_drawer.dart';

String _joinUrl(String base, String path) {
  final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  final p = path.startsWith('/') ? path.substring(1) : path;
  return '$b/$p';
}

class ContractorHomeScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final String baseUrl;
  final Future<void> Function() onRefreshUser;

  const ContractorHomeScreen({
    super.key,
    required this.user,
    required this.baseUrl,
    required this.onRefreshUser,
  });

  @override
  State<ContractorHomeScreen> createState() => _ContractorHomeScreenState();
}

class _ContractorHomeScreenState extends State<ContractorHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ProjectService _projectService = ProjectService();

  Map<String, dynamic>? _userLocal;

  Future<List<dynamic>>? _availableFuture;
  Future<List<dynamic>>? _myFuture;

  @override
  void initState() {
    super.initState();
    _syncUserAndLoad();
  }

  @override
  void didUpdateWidget(covariant ContractorHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _syncUserAndLoad();
    }
  }

  Future<void> _syncUserAndLoad() async {
    final u = widget.user ?? await SessionService.getUser();
    if (!mounted) return;

    setState(() => _userLocal = u);

    final role = (u?["role"] ?? "").toString().toLowerCase().trim();
    if (role != "contractor") {
      // لو دخل غلط، خلّيها فاضية
      setState(() {
        _availableFuture = Future.value([]);
        _myFuture = Future.value([]);
      });
      return;
    }

    setState(() {
      _availableFuture = _projectService.getAvailableProjectsForContractor();
      _myFuture = _projectService.getMyProjectsForContractor();
    });
  }

  Future<void> _refreshAll() async {
    await widget.onRefreshUser();
    await _syncUserAndLoad();
  }

  @override
  Widget build(BuildContext context) {
    const bgTop = Color(0xFF0F261F);
    const bgBottom = Color(0xFF0B1D17);
    const primary = Color(0xFF8BE3B5);

    final user = _userLocal;
    final name = (user?["name"] ?? "Contractor").toString();

    final profilePath = (user?["profileImage"] ?? user?["avatar"] ?? "").toString();
    final profileUrl = profilePath.isNotEmpty ? _joinUrl(widget.baseUrl, profilePath) : null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgTop,

      // ✅ Drawer نفس العميل
      drawer: user == null
          ? null
          : AppDrawer(
              user: user,
              baseUrl: widget.baseUrl,
              onRefreshUser: () async {
                await widget.onRefreshUser();
                await _syncUserAndLoad();
              },
            ),

      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bgTop, bgBottom],
            ),
          ),
          child: RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                // ===== Top Bar (مثل صفحة العميل) =====
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (user == null) return;
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white12,
                        backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                        child: profileUrl == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Home',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.notifications_none, color: Colors.white),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Text(
                  "Welcome back, $name",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 14),

                // ===== Tabs (Available / My Projects) =====
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
                            color: primary,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          tabs: [
                            Tab(text: "Available Projects"),
                            Tab(text: "My Projects"),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 520, // مساحة للقائمة
                          child: TabBarView(
                            children: [
                              _ProjectsList(
                                future: _availableFuture,
                                emptyText: "No available projects right now.",
                              ),
                              _ProjectsList(
                                future: _myFuture,
                                emptyText: "You don't have assigned projects yet.",
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
        ),
      ),
    );
  }
}

class _ProjectsList extends StatelessWidget {
  final Future<List<dynamic>>? future;
  final String emptyText;

  const _ProjectsList({required this.future, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    const card = Color(0xFF1B3A35);

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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Error: ${snap.error}",
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          );
        }

        final items = snap.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Text(emptyText, style: const TextStyle(color: Colors.white70)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final p = (items[i] as Map).cast<String, dynamic>();

            final title = (p["title"] ?? p["name"] ?? "Project").toString();
            final location = (p["location"] ?? "").toString();
            final status = (p["status"] ?? "").toString();

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (location.isNotEmpty)
                    Text(location, style: const TextStyle(color: Colors.white70)),
                  if (status.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text("Status: $status", style: const TextStyle(color: Colors.white60)),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        // TODO: open project details
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

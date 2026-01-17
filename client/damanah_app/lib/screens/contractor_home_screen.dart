import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/session_service.dart';
import '../services/project_service.dart';
import '../services/jcca_news_service.dart';
import 'app_drawer.dart';
import 'contractor_project_details_page.dart';

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

  final JccaNewsService _newsService = JccaNewsService();
  Future<List<Map<String, dynamic>>>? _newsFuture;

  Map<String, dynamic>? _userLocal;
  Future<List<dynamic>>? _availableFuture;

  @override
  void initState() {
    super.initState();
    _syncUserAndLoad();
    _newsFuture = _newsService.fetchNews(limit: 5);
  }

  @override
  void didUpdateWidget(covariant ContractorHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) _syncUserAndLoad();
  }

  Future<void> _syncUserAndLoad() async {
    final u = widget.user ?? await SessionService.getUser();
    if (!mounted) return;

    setState(() => _userLocal = u);

    final role = (u?["role"] ?? "").toString().toLowerCase().trim();
    if (role != "contractor") {
      setState(() => _availableFuture = Future.value([]));
      return;
    }

    setState(() {
      _availableFuture = _projectService.getAvailableProjectsForContractor();
    });
  }

  Future<void> _refreshAll() async {
    await widget.onRefreshUser();
    await _syncUserAndLoad();
    setState(() => _newsFuture = _newsService.fetchNews(limit: 5));
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openProjectDetails(String projectId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContractorProjectDetailsPage(projectId: projectId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgTop = Color(0xFF0F261F);
    const bgBottom = Color(0xFF0B1D17);
    const card = Color(0xFF1B3A35);

    final user = _userLocal;
    final name = (user?["name"] ?? "Contractor").toString();
    final profilePath =
        (user?["profileImage"] ?? user?["avatar"] ?? "").toString();
    final profileUrl =
        profilePath.isNotEmpty ? _joinUrl(widget.baseUrl, profilePath) : null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgTop,
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
                // Top Bar
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
                        backgroundImage:
                            profileUrl != null ? NetworkImage(profileUrl) : null,
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
                      icon: const Icon(Icons.notifications_none,
                          color: Colors.white),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Text(
                  "Welcome back,\n$name",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 14),

                // ✅ Client requests only
                const Text(
                  "Client Requests",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),

                _ProjectsList(
                  future: _availableFuture,
                  emptyText: "No client requests right now.",
                  onOpenDetails: _openProjectDetails,
                ),

                const SizedBox(height: 18),

                // ✅ News
                const Text(
                  "Latest JCCA News",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 150,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _newsFuture,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Text(
                            "Loading news...",
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      if (snap.hasError) {
                        return const Center(
                          child: Text(
                            "Couldn't load news.",
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      final items = snap.data ?? [];
                      if (items.isEmpty) {
                        return const Center(
                          child: Text(
                            "No news available.",
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final n = items[i];
                          final rawTitle = (n["title"] ?? "").toString().trim();
                          final title = rawTitle.isNotEmpty
                              ? rawTitle
                              : "New update from JCCA";
                          final link = (n["link"] ?? "").toString();

                          return InkWell(
                            onTap: () => _openUrl(link),
                            child: Container(
                              width: 260,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.newspaper,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    title,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                    ),
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: const [
                                      Icon(Icons.open_in_new,
                                          color: Colors.white54, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        "Read more",
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
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
  final void Function(String projectId) onOpenDetails;

  const _ProjectsList({
    required this.future,
    required this.emptyText,
    required this.onOpenDetails,
  });

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
          return Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              "Error: ${snap.error}",
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final items = snap.data ?? [];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child:
                Text(emptyText, style: const TextStyle(color: Colors.white70)),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
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
                        onOpenDetails(id);
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

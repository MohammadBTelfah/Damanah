import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/session_service.dart';
import '../services/project_service.dart';
import '../services/contract_service.dart';
import '../services/jcca_news_service.dart';
import '../services/notification_service.dart';
import 'app_drawer.dart';
import 'contractor_project_details_page.dart';
import 'contractor_stats_pages.dart';
import 'my_contracts_page.dart';
import 'my_offers_page.dart';
import 'contractor_notifications_page.dart'; // ✅ الاستدعاء الجديد

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
  final ContractService _contractService = ContractService();
  final JccaNewsService _newsService = JccaNewsService();

  // State
  Map<String, dynamic>? _userLocal;
  Future<List<dynamic>>? _availableProjectsFuture;
  Future<List<Map<String, dynamic>>>? _newsFuture;

  // إحصائيات
  int _worksCount = 0;
  int _offersCount = 0;
  int _contractsCount = 0;
  bool _loadingStats = true;

  // ✅✅✅ (تعديل) عداد الإشعارات غير المقروءة
  int _unreadNotifications = 0;
  bool _loadingNotiCount = true;

  // للتحريك التلقائي للأخبار
  final PageController _newsPageController = PageController(viewportFraction: 0.85);
  int _currentNewsPage = 0;
  Timer? _newsTimer;

  @override
  void initState() {
    super.initState();
    _syncUserAndLoad();
    _loadNews();
    _loadDashboardStats();
    _loadNotificationCount(); // ✅✅✅ (تعديل) تحميل عداد الإشعارات
  }

  @override
  void dispose() {
    _newsTimer?.cancel();
    _newsPageController.dispose();
    super.dispose();
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
    setState(() {
      _availableProjectsFuture = _projectService.getAvailableProjectsForContractor();
    });
  }

  Future<void> _loadDashboardStats() async {
    if (!mounted) return;
    setState(() => _loadingStats = true);

    int works = 0;
    int offers = 0;
    int contracts = 0;

    try {
      final res = await _projectService.getMyProjectsForContractor();
      works = res.length;
    } catch (_) {}

    try {
      final res = await _contractService.getMyContracts();
      contracts = res.length;
    } catch (_) {}

    try {
      final res = await _projectService.getMyOffers();
      offers = res.length;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _worksCount = works;
      _contractsCount = contracts;
      _offersCount = offers;
      _loadingStats = false;
    });
  }

  // ✅✅✅ (تعديل) تحميل عداد الإشعارات (غير المقروءة)
  Future<void> _loadNotificationCount() async {
    if (!mounted) return;
    setState(() => _loadingNotiCount = true);

    try {
      final list = await NotificationService().getMyNotifications(); // لازم تكون موجودة
      final unread = list.where((n) => (n is Map && n['read'] == false)).length;

      if (!mounted) return;
      setState(() {
        _unreadNotifications = unread;
        _loadingNotiCount = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _unreadNotifications = 0;
        _loadingNotiCount = false;
      });
    }
  }

  void _loadNews() {
    setState(() {
      _newsFuture = _newsService.fetchNews(limit: 5).then((news) {
        if (news.isNotEmpty) _startAutoScroll(news.length);
        return news;
      });
    });
  }

  void _startAutoScroll(int totalPages) {
    _newsTimer?.cancel();
    _newsTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_newsPageController.hasClients) {
        _currentNewsPage++;
        if (_currentNewsPage >= totalPages) {
          _currentNewsPage = 0;
          _newsPageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 800),
            curve: Curves.fastOutSlowIn,
          );
        } else {
          _newsPageController.animateToPage(
            _currentNewsPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  Future<void> _refreshAll() async {
    await widget.onRefreshUser();
    await _syncUserAndLoad();
    _loadNews();
    await _loadDashboardStats();
    await _loadNotificationCount(); // ✅✅✅ (تعديل) يحدث العداد عند السحب
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

    final user = _userLocal;
    final name = (user?["name"] ?? "Contractor").toString();
    final profilePath = (user?["profileImage"] ?? "").toString();

    final profileUrl = (profilePath.isNotEmpty && !profilePath.startsWith("http"))
        ? _joinUrl(widget.baseUrl, profilePath)
        : (profilePath.startsWith("http") ? profilePath : null);

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
            color: const Color(0xFF9EE7B7),
            backgroundColor: const Color(0xFF1B3A35),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (user == null) return;
                            _scaffoldKey.currentState?.openDrawer();
                          },
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.white12,
                            backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                            child: profileUrl == null
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                        ),
                        const Spacer(),

                        // ✅✅✅ (تعديل) جرس الإشعارات + عداد
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ContractorNotificationsPage()),
                                );
                                _loadNotificationCount(); // يحدث العداد بعد الرجوع
                              },
                              icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
                            ),

                            if (!_loadingNotiCount && _unreadNotifications > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF9EE7B7), // ✅ أخضر
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF0F261F), width: 2),
                                  ),
                                  child: Text(
                                    _unreadNotifications > 99 ? "99+" : "$_unreadNotifications",
                                    style: const TextStyle(
                                      color: Color(0xFF0F261F),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "Welcome back,\n$name",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Overview Section
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "Overview",
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _OverviewCard(
                            title: "My Works",
                            count: _loadingStats ? "-" : "$_worksCount",
                            icon: Icons.engineering,
                            color: const Color(0xFFFFA726), // Orange
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyWorksPage())),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OverviewCard(
                            title: "Offers",
                            count: _loadingStats ? "-" : "$_offersCount",
                            icon: Icons.local_offer,
                            color: const Color(0xFF29B6F6), // Blue
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOffersPage())),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OverviewCard(
                            title: "Contracts",
                            count: _loadingStats ? "-" : "$_contractsCount",
                            icon: Icons.description,
                            color: const Color(0xFF66BB6A), // Green
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyContractsPage())),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Client Requests
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "Client Requests",
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _ProjectsList(
                      future: _availableProjectsFuture,
                      emptyText: "No client requests right now.",
                      onOpenDetails: _openProjectDetails,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // JCCA News (Auto-Scrolling)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "Latest JCCA News",
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 160,
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _newsFuture,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF9EE7B7)));
                        }
                        final newsList = snap.data ?? [];

                        if (newsList.isEmpty) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(child: Text("No news available.", style: TextStyle(color: Colors.white54))),
                          );
                        }

                        return PageView.builder(
                          controller: _newsPageController,
                          itemCount: newsList.length,
                          padEnds: false,
                          itemBuilder: (context, index) {
                            final newsItem = newsList[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                left: 20,
                                right: index == newsList.length - 1 ? 20 : 0,
                              ),
                              child: _NewsCard(
                                title: newsItem['title'] ?? "News Update",
                                link: newsItem['link'] ?? "",
                                onTap: _openUrl,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ... (Helper Widgets: _OverviewCard, _ProjectsList, _ProjectCard, _NewsCard تبقى كما هي)
class _OverviewCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _OverviewCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1B3A35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                count,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectsList extends StatelessWidget {
  final Future<List<dynamic>>? future;
  final String emptyText;
  final Function(String) onOpenDetails;

  const _ProjectsList({
    required this.future,
    required this.emptyText,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LinearProgressIndicator(color: Color(0xFF9EE7B7), backgroundColor: Colors.white10));
        }

        final projects = snapshot.data ?? [];

        if (projects.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1B3A35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Text(
              emptyText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: projects.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final project = projects[index];

            final status = project['status'] ?? "open";
            final isDirectRequest = status == 'pending';

            return _ProjectCard(
              title: project['title'] ?? "Untitled Project",
              location: project['location'] ?? "Unknown Location",
              status: status,
              isDirectRequest: isDirectRequest,
              onTap: () => onOpenDetails(project['_id'] ?? project['id']),
            );
          },
        );
      },
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final String title;
  final String location;
  final String status;
  final bool isDirectRequest;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.title,
    required this.location,
    required this.status,
    required this.isDirectRequest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1B3A35),
            borderRadius: BorderRadius.circular(16),
            border: isDirectRequest
                ? Border.all(color: const Color(0xFFFFA726).withOpacity(0.5))
                : Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDirectRequest
                      ? const Color(0xFFFFA726).withOpacity(0.15)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDirectRequest ? Icons.person_add_alt_1 : Icons.assignment_outlined,
                  color: isDirectRequest ? const Color(0xFFFFA726) : const Color(0xFF9EE7B7),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDirectRequest)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFA726),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text("FOR YOU", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          location,
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final String title;
  final String link;
  final Function(String) onTap;

  const _NewsCard({
    required this.title,
    required this.link,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(link),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1B3A35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.article, color: Colors.white, size: 18),
                ),
                const Spacer(),
                const Icon(Icons.arrow_outward, color: Color(0xFF9EE7B7), size: 18),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Read full article",
              style: TextStyle(
                color: Color(0xFF9EE7B7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

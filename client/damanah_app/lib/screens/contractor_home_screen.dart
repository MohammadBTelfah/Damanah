import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/session_service.dart';
import '../services/project_service.dart';
import '../services/contract_service.dart'; // ✅ استدعاء سيرفس العقود الجديد
import '../services/jcca_news_service.dart';
import 'app_drawer.dart';
import 'contractor_project_details_page.dart';
import 'contractor_stats_pages.dart'; 

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
  
  // ✅ تعريف الخدمات بناءً على الملفات التي أرسلتها
  final ProjectService _projectService = ProjectService();
  final ContractService _contractService = ContractService(); // ✅ هنا نستخدم سيرفس العقود
  final JccaNewsService _newsService = JccaNewsService();

  // State
  Map<String, dynamic>? _userLocal;
  Future<List<dynamic>>? _availableProjectsFuture;
  Future<List<Map<String, dynamic>>>? _newsFuture;

  // إحصائيات لوحة التحكم
  int _worksCount = 0;
  int _offersCount = 0;
  int _contractsCount = 0;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _syncUserAndLoad();
    _loadNews();
    _loadDashboardStats(); // ✅ تحميل الأرقام عند فتح الصفحة
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

    // تحميل المشاريع المتاحة (Client Requests) باستخدام ProjectService
    setState(() {
      _availableProjectsFuture = _projectService.getAvailableProjectsForContractor();
    });
  }

  // ✅ دالة جلب الإحصائيات (معدلة حسب ملفاتك)
  Future<void> _loadDashboardStats() async {
    if (!mounted) return;
    setState(() => _loadingStats = true);

    // متغيرات مؤقتة
    int works = 0;
    int offers = 0;
    int contracts = 0;

    // 1. محاولة جلب الأعمال (My Works)
    try {
      final res = await _projectService.getMyProjectsForContractor();
      works = res.length;
    } catch (e) {
      print("Error loading works: $e");
    }

    // 2. محاولة جلب العقود (Contracts)
    try {
      final res = await _contractService.getMyContracts();
      contracts = res.length;
    } catch (e) {
      print("Error loading contracts: $e");
      // غالباً الخطأ هنا لأن صيغة الرد قد تكون Map وليست List
    }

    // 3. محاولة جلب العروض (Offers)
    try {
      // final res = await _projectService.getMyOffers(); 
      // offers = res.length;
      offers = 0; // مؤقتاً حتى تجهز الـ API
    } catch (e) {
      print("Error loading offers: $e");
    }

    if (!mounted) return;
    
    // تحديث الواجهة بالأرقام التي نجحنا في جلبها
    setState(() {
      _worksCount = works;
      _contractsCount = contracts;
      _offersCount = offers;
      _loadingStats = false;
    });
  }

  void _loadNews() {
    setState(() {
      _newsFuture = _newsService.fetchNews(limit: 5);
    });
  }

  Future<void> _refreshAll() async {
    await widget.onRefreshUser();
    await _syncUserAndLoad();
    _loadNews();
    await _loadDashboardStats(); // تحديث الأرقام عند السحب
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              children: [
                // 1. Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (user == null) return;
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white12,
                        backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                        child: profileUrl == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {}, 
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Text(
                  "Welcome back,\n$name",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 24),

                // ===============================================
                // ✅ 2. OVERVIEW SECTION (My Works, Offers, Contracts)
                // ===============================================
                const Text(
                  "Overview",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: "My Works",
                        count: _loadingStats ? "..." : "$_worksCount",
                        icon: Icons.engineering,
                        color: const Color(0xFFFFA726), // Orange
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyWorksPage()));
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: "Offers",
                        count: _loadingStats ? "..." : "$_offersCount",
                        icon: Icons.local_offer,
                        color: const Color(0xFF29B6F6), // Light Blue
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOffersPage()));
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: "Contracts",
                        count: _loadingStats ? "..." : "$_contractsCount",
                        icon: Icons.description,
                        color: const Color(0xFF66BB6A), // Green
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyContractsPage()));
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // 3. Client Requests
                const Text(
                  "Client Requests",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                _ProjectsList(
                  future: _availableProjectsFuture,
                  emptyText: "No client requests right now.",
                  onOpenDetails: _openProjectDetails,
                ),

                const SizedBox(height: 30),

                // 4. News
                const Text(
                  "Latest JCCA News",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  height: 170,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _newsFuture,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF9EE7B7)));
                      }
                      final newsList = snap.data ?? [];
                      
                      if (newsList.isEmpty) {
                        return Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(child: Text("No news available.", style: TextStyle(color: Colors.white54))),
                        );
                      }

                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: newsList.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final newsItem = newsList[index];
                          return _NewsCard(
                            title: newsItem['title'] ?? "News Update",
                            link: newsItem['link'] ?? "",
                            onTap: _openUrl,
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

// ================== HELPER WIDGETS ==================

class _StatCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B3A35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                count,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
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
              border: Border.all(color: Colors.white10),
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
            return _ProjectCard(
              title: project['title'] ?? "Untitled Project",
              location: project['location'] ?? "Unknown Location",
              status: project['status'] ?? "Open",
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
  final VoidCallback onTap;

  const _ProjectCard({
    required this.title,
    required this.location,
    required this.status,
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
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_outlined, color: Color(0xFF9EE7B7)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF234540),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.newspaper, color: Colors.white, size: 20),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Text("Read more", style: TextStyle(color: Color(0xFF9EE7B7), fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, color: Color(0xFF9EE7B7), size: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
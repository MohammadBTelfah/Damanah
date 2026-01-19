import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart'; // ✅ تأكد أنك أضفت المكتبة
import '../services/session_service.dart';
import '../services/notification_service.dart';
import '../services/project_service.dart'; 
import 'app_drawer.dart';
import 'create_project_flow.dart';
import 'my_projects_page.dart';
import 'contractors_page.dart';
import 'notifications_page.dart';
import 'contracts_page.dart';
import 'project_details_page.dart';

String _joinUrl(String base, String path) {
  final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  final p = path.startsWith('/') ? path.substring(1) : path;
  return '$b/$p';
}

// ✅ دالة مساعدة ذكية للتعامل مع روابط الصور (Cloudinary أو Local)
String? _getSmartUrl(String? path, String baseUrl) {
  if (path == null || path.trim().isEmpty) return null;
  final s = path.trim();
  if (s.startsWith('http')) return s; // رابط Cloudinary كامل
  return _joinUrl(baseUrl, s); // رابط محلي قديم
}

class ClientHomeScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final String baseUrl;
  final Future<void> Function() onRefreshUser;
  final VoidCallback onOpenProfile;

  const ClientHomeScreen({
    super.key,
    required this.user,
    required this.baseUrl,
    required this.onRefreshUser,
    required this.onOpenProfile,
  });

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? _userLocal;
  final _notifService = NotificationService();
  final _projectService = ProjectService(); 
  int _unreadCount = 0;
  Future<List<dynamic>>? _tipsFuture;
  Future<List<dynamic>>? _offersFuture; 

  @override
  void initState() {
    super.initState();
    _syncUser();
    _loadUnread();
    _loadData(); 
  }

  @override
  void didUpdateWidget(covariant ClientHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _syncUser();
    }
  }

  Future<void> _syncUser() async {
    if (widget.user != null) {
      if (mounted) setState(() => _userLocal = widget.user);
      return;
    }
    final u = await SessionService.getUser();
    if (mounted) setState(() => _userLocal = u);
  }

  Future<void> _loadUnread() async {
    try {
      final c = await _notifService.getUnreadCount();
      if (mounted) setState(() => _unreadCount = c);
    } catch (_) {}
  }

  void _loadData() {
    setState(() {
      _tipsFuture = _projectService.getTips();
      _offersFuture = _projectService.getRecentOffers(); 
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgTop = Color(0xFF0E221C);
    const bgBottom = Color(0xFF0A1511);
    final user = _userLocal;
    final name = (user?["name"] ?? "User").toString();
    
    // ✅ استخدام الدالة الذكية لبروفايل المستخدم
    final String? profileUrl = _getSmartUrl(user?["profileImage"], widget.baseUrl);

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
                await _syncUser();
                await _loadUnread();
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
            onRefresh: () async {
              await widget.onRefreshUser();
              await _syncUser();
              await _loadUnread();
              _loadData(); 
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (user == null) return;
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white12,
                        backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                        child: profileUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text('Damanah', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      ),
                    ),
                    Stack(
                      children: [
                        IconButton(
                          onPressed: () async {
                            setState(() => _unreadCount = 0);
                            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
                            _loadUnread();
                          },
                          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                        ),
                        if (_unreadCount > 0)
                          Positioned(
                            right: 8, top: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF9EE7B7), borderRadius: BorderRadius.circular(10)),
                              constraints: const BoxConstraints(minWidth: 16),
                              child: Text(_unreadCount > 99 ? "99+" : "$_unreadCount", textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Welcome
                Text("Hello, $name 👋", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text("Manage your construction projects easily.", style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 24),

                // Quick Actions
                const Text("Quick Actions", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _GridActionCard(
                      icon: Icons.add_circle_outline, title: "New Project", color: const Color(0xFF9EE7B7), textColor: Colors.black,
                      onTap: () async {
                        final done = await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => DraggableScrollableSheet(
                            initialChildSize: 0.92, minChildSize: 0.7, maxChildSize: 0.98,
                            builder: (_, sc) => CreateProjectFlow(scrollController: sc),
                          ),
                        );
                        if (done == true) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Project created successfully"), backgroundColor: Colors.green));
                          _loadUnread();
                        }
                      },
                    ),
                    _GridActionCard(icon: Icons.dashboard_outlined, title: "My Projects", onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyProjectsPage()))),
                    _GridActionCard(icon: Icons.description_outlined, title: "Contracts", onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContractsPage()))),
                    _GridActionCard(icon: Icons.engineering_outlined, title: "Contractors", onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContractorsPage()))),
                  ],
                ),
                const SizedBox(height: 28),

                // Recent Updates (Carousel)
                const Text("Recent Updates", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                FutureBuilder<List<dynamic>>(
                  future: _offersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: LinearProgressIndicator(color: Color(0xFF9EE7B7), backgroundColor: Colors.white10));
                    final offers = snapshot.data ?? [];
                    if (offers.isEmpty) return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF15221D), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))), child: const Row(children: [Icon(Icons.notifications_off_outlined, color: Colors.white38), SizedBox(width: 12), Text("No recent offers received.", style: TextStyle(color: Colors.white54))]));
                    return CarouselSlider.builder(
                      itemCount: offers.length,
                      options: CarouselOptions(height: 110, autoPlay: true, autoPlayInterval: const Duration(seconds: 6), viewportFraction: 1.0, enableInfiniteScroll: offers.length > 1),
                      itemBuilder: (context, index, _) {
                        final offer = offers[index];
                        // ✅ معالجة ذكية لصورة المقاول
                        String? img = _getSmartUrl(offer["contractorImage"], widget.baseUrl);
                        
                        return _ProjectOfferCard(
                          from: offer["contractorName"] ?? "Unknown",
                          title: "Offer on: ${offer["projectTitle"] ?? "Project"}",
                          subtitle: "Price: ${offer["price"]?.toString() ?? "0"} JOD",
                          imageUrl: img,
                          onTap: () {
                            final pid = offer["projectId"];
                            if (pid != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailsPage(projectId: pid)));
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 28),

                // Community Tips (Carousel)
                const Text("Community & Tips", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: FutureBuilder<List<dynamic>>(
                    future: _tipsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF9EE7B7)));
                      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No tips available yet", style: TextStyle(color: Colors.white38)));
                      final tips = snapshot.data!;
                      return CarouselSlider.builder(
                        itemCount: tips.length,
                        options: CarouselOptions(height: 240, autoPlay: true, autoPlayInterval: const Duration(seconds: 5), enlargeCenterPage: true, viewportFraction: 0.6, aspectRatio: 2.0),
                        itemBuilder: (context, i, _) {
                          final item = tips[i];
                          // ✅ معالجة ذكية لصورة النصيحة
                          String? img = _getSmartUrl(item["imageUrl"], widget.baseUrl);

                          return _CommunityCard(
                            imageUrl: img ?? "",
                            title: item["title"] ?? "No Title",
                            subtitle: item["subtitle"] ?? "",
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TipDetailsPage(tip: item, baseUrl: widget.baseUrl))),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== WIDGETS =====================

class _GridActionCard extends StatelessWidget {
  final IconData icon; final String title; final VoidCallback? onTap; final Color? color; final Color? textColor;
  const _GridActionCard({required this.icon, required this.title, this.onTap, this.color, this.textColor});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(decoration: BoxDecoration(color: color ?? const Color(0xFF15221D), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (textColor ?? Colors.white).withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: textColor ?? const Color(0xFF9EE7B7), size: 28)), const SizedBox(height: 10), Text(title, style: TextStyle(color: textColor ?? Colors.white, fontWeight: FontWeight.w600, fontSize: 15))]))),
    );
  }
}

class _ProjectOfferCard extends StatelessWidget {
  final String from; final String title; final String subtitle; final String? imageUrl; final VoidCallback? onTap;
  const _ProjectOfferCard({required this.from, required this.title, required this.subtitle, this.imageUrl, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: Container(decoration: BoxDecoration(color: const Color(0xFF15221D), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.06))), padding: const EdgeInsets.all(12), child: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(14), child: Container(height: 70, width: 70, color: Colors.white10, child: (imageUrl != null && imageUrl!.trim().isNotEmpty) ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54)) : const Icon(Icons.local_offer, color: Colors.white54))), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(from, style: const TextStyle(color: Color(0xFF9EE7B7), fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13))])), const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16), const SizedBox(width: 8)]))));
  }
}

class _CommunityCard extends StatelessWidget {
  final String imageUrl; final String title; final String subtitle; final VoidCallback? onTap;
  const _CommunityCard({required this.imageUrl, required this.title, required this.subtitle, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: Container(width: 200, decoration: BoxDecoration(color: const Color(0xFF15221D), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.06))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(18)), child: Hero(tag: title, child: (imageUrl.isNotEmpty) ? Image.network(imageUrl, height: 110, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 110, color: Colors.white10, child: const Icon(Icons.image_not_supported, color: Colors.white24))) : Container(height: 110, color: Colors.white10, child: const Icon(Icons.image, color: Colors.white24)))), Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.3))]))]))));
  }
}

class TipDetailsPage extends StatelessWidget {
  final Map<String, dynamic> tip; final String baseUrl;
  const TipDetailsPage({super.key, required this.tip, required this.baseUrl});
  
  @override
  Widget build(BuildContext context) {
    // ✅ استخدام المعالجة الذكية في صفحة التفاصيل
    final img = _getSmartUrl(tip["imageUrl"], baseUrl) ?? "";
    final title = tip["title"] ?? "Details";
    final content = tip["content"] ?? "No content available.";
    
    return Scaffold(backgroundColor: const Color(0xFF0E1814), extendBodyBehindAppBar: true, appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)))), body: SingleChildScrollView(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (img.isNotEmpty) Hero(tag: title, child: ClipRRect(borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)), child: Image.network(img, width: double.infinity, height: 350, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 350, color: Colors.white10, child: const Icon(Icons.broken_image, size: 50, color: Colors.white54))))), Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.2)), const SizedBox(height: 16), Container(width: 60, height: 4, decoration: BoxDecoration(color: const Color(0xFF9EE7B7), borderRadius: BorderRadius.circular(2))), const SizedBox(height: 24), Text(content, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16, height: 1.8, fontWeight: FontWeight.w400)), const SizedBox(height: 40)]))])));
  }
}
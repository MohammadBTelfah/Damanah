import 'package:flutter/material.dart';
import '../services/session_service.dart';
import 'app_drawer.dart';

class ClientHomeScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final String baseUrl;

  /// يعيد تحميل المستخدم من Session داخل MainShell
  final Future<void> Function() onRefreshUser;

  /// (اختياري) إذا بدك تفتح Profile من MainShell
  final Future<void> Function() onOpenProfile;

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

  Map<String, dynamic>? _userLocal; // fallback لو widget.user null

  @override
  void initState() {
    super.initState();
    _syncUser();
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

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0F261F);
    const cardColor = Color(0xFF0F261F);

    final user = _userLocal;
    final name = (user?["name"] ?? "User").toString();
    final profileImage = user?["profileImage"];

    final String? profileUrl =
        (profileImage != null && profileImage.toString().isNotEmpty)
            ? "${widget.baseUrl}/${profileImage.toString()}"
            : null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,

      // ✅ Drawer (موجود فقط إذا user موجود)
      drawer: user == null
          ? null
          : AppDrawer(
              user: user,
              baseUrl: widget.baseUrl,

              // ✅ أهم تعديل: لازم ترجع Future<void>
              onRefreshUser: () async {
                await widget.onRefreshUser(); // يحدث Session داخل MainShell
                await _syncUser();            // يحدث واجهة Home
              },
            ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await widget.onRefreshUser();
            await _syncUser();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== Top Bar =====
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (user == null) return;
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white24,
                        backgroundImage:
                            profileUrl != null ? NetworkImage(profileUrl) : null,
                        child: profileUrl == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Home',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.settings_outlined, color: Colors.white),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ===== Welcome =====
                Text(
                  "Welcome back, $name",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 24),

                // ===== Quick Actions =====
                const Text(
                  "Quick Actions",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: const [
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.add,
                        title: "New Project",
                        subtitle: "Start a new project",
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.list_alt_outlined,
                        title: "My Projects",
                        subtitle: "Track your ongoing projects",
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: const [
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.insert_drive_file_outlined,
                        title: "Contracts",
                        subtitle: "Manage your contracts",
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.groups_outlined,
                        title: "Contractors",
                        subtitle: "View and manage contractors",
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ===== Project Offers =====
                const Text(
                  "Project Offers",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Offer from BuildRight",
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "Kitchen Remodel",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "View offer details",
                              style: TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 70,
                        width: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.green,
                        ),
                        child: const Icon(
                          Icons.kitchen_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== Widget لبطاقات Quick Actions =====
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFF1B3A35);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white10,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

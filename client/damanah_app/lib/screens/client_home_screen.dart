import 'package:flutter/material.dart';
import '../services/session_service.dart';
import 'app_drawer.dart';
import 'create_project_flow.dart'; // ✅ جديد

String _joinUrl(String base, String path) {
  final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  final p = path.startsWith('/') ? path.substring(1) : path;
  return '$b/$p';
}

class ClientHomeScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final String baseUrl;

  /// يعيد تحميل المستخدم من Session داخل MainShell
  final Future<void> Function() onRefreshUser;

  /// (اختياري) إذا بدك تفتح Profile من MainShell
  final VoidCallback onOpenProfile; // ✅ هيك

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
    const bgTop = Color(0xFF0E221C);
    const bgBottom = Color(0xFF0A1511);

    final user = _userLocal;
    final name = (user?["name"] ?? "User").toString();
    final profileImage = user?["profileImage"];

    final String? profileUrl =
        (profileImage != null && profileImage.toString().trim().isNotEmpty)
        ? _joinUrl(widget.baseUrl, profileImage.toString().trim())
        : null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgTop,

      // ✅ Drawer
      drawer: user == null
          ? null
          : AppDrawer(
              user: user,
              baseUrl: widget.baseUrl,
              onRefreshUser: () async {
                await widget.onRefreshUser();
                await _syncUser();
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
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                // ===== Top Bar (مثل الصورة الثانية) =====
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
                        backgroundImage: profileUrl != null
                            ? NetworkImage(profileUrl)
                            : null,
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
                      onPressed: () {
                        // TODO: افتح settings screen
                      },
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // ===== Welcome =====
                Text(
                  "Welcome back, $name",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 18),

                // ===== Quick Actions (تحويلها لستايل List مثل الصورة الثانية) =====
                const Text(
                  "Quick Actions",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),

                _ActionTile(
                  icon: Icons.add,
                  title: "New Project",
                  subtitle: "Start a new project",
                  onTap: () async {
                    final done = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) {
                        return DraggableScrollableSheet(
                          initialChildSize: 0.92,
                          minChildSize: 0.7,
                          maxChildSize: 0.98,
                          builder: (context, scrollController) {
                            return CreateProjectFlow(
                              scrollController: scrollController,
                            );
                          },
                        );
                      },
                    );

                    if (done == true) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Project created successfully"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),

                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.list_alt_outlined,
                  title: "My Projects",
                  subtitle: "Track your ongoing projects",
                  onTap: () {},
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.insert_drive_file_outlined,
                  title: "Contracts",
                  subtitle: "Manage your contracts",
                  onTap: () {},
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.groups_outlined,
                  title: "Contractors",
                  subtitle: "View and manage contractors",
                  onTap: () {},
                ),

                const SizedBox(height: 24),

                // ===== Project Offers (صارت فيها صورة/ثَمبنيل يمين مثل الصورة الثانية) =====
                const Text(
                  "Project Offers",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                _ProjectOfferCard(
                  from: "Offer from BuildRight",
                  title: "Kitchen Remodel",
                  subtitle: "View offer details",
                  // حط رابط صورة حقيقي إذا عندك
                  imageUrl:
                      "https://images.unsplash.com/photo-1556912172-45b7abe8b7e1?auto=format&fit=crop&w=800&q=60",
                  onTap: () {},
                ),

                const SizedBox(height: 24),

                // ===== Community (قسم جديد مثل الصورة الثانية) =====
                const Text(
                  "Community",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 170,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _communityItems.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final item = _communityItems[i];
                      return _CommunityCard(
                        imageUrl: item.imageUrl,
                        title: item.title,
                        subtitle: item.subtitle,
                        onTap: () {},
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

/* ===================== Widgets ===================== */

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const tileColor = Color(0xFF0F261F); // قريب جداً من ستايل الصورة
    const iconBox = Color(0xFF17362F);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: tileColor.withOpacity(0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: iconBox.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectOfferCard extends StatelessWidget {
  final String from;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;

  const _ProjectOfferCard({
    required this.from,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFF0F261F);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor.withOpacity(0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      from,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 62,
                  width: 98,
                  color: Colors.white10,
                  child: (imageUrl != null && imageUrl!.trim().isNotEmpty)
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.white54,
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.kitchen_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _CommunityCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFF0F261F);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 190,
          decoration: BoxDecoration(
            color: cardColor.withOpacity(0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: Image.network(
                  imageUrl,
                  height: 105,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 105,
                    color: Colors.white10,
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ===================== Demo Data (بدّلها من API) ===================== */

class _CommunityItem {
  final String imageUrl;
  final String title;
  final String subtitle;
  const _CommunityItem({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
  });
}

const _communityItems = <_CommunityItem>[
  _CommunityItem(
    imageUrl:
        "https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=800&q=60",
    title: "Tips for Home Renovation",
    subtitle: "Learn how to plan your renovation",
  ),
  _CommunityItem(
    imageUrl:
        "https://images.unsplash.com/photo-1562259949-1f7bd7689f5b?auto=format&fit=crop&w=800&q=60",
    title: "Choosing the Right Contractor",
    subtitle: "Find the best contractor for your needs",
  ),
  _CommunityItem(
    imageUrl:
        "https://images.unsplash.com/photo-1505691938895-1758d7feb511?auto=format&fit=crop&w=800&q=60",
    title: "Maintenance Checklist",
    subtitle: "Keep your home in top shape",
  ),
];

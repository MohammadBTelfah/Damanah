import 'package:flutter/material.dart';
import '../services/session_service.dart';
import 'profile_screen.dart';
import 'role_selection_screen.dart';
import 'create_project_flow.dart'; // ✅ صفحة إنشاء مشروع
import 'my_projects_page.dart'; // ✅ صفحة مشاريعي
import 'contractors_page.dart'; // ✅ صفحة المقاولين
import 'contracts_page.dart';
import 'my_offers_page.dart'; // ✅ صفحة عروضي
import 'my_contracts_page.dart'; // ✅ صفحة عقودي

class AppDrawer extends StatefulWidget {
  final Map<String, dynamic> user;
  final String baseUrl;
  final Future<void> Function() onRefreshUser;

  const AppDrawer({
    super.key,
    required this.user,
    required this.baseUrl,
    required this.onRefreshUser,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  Map<String, dynamic>? _user;
  int _bust = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final sessionUser = await SessionService.getUser();
    if (!mounted) return;
    setState(() {
      _user = sessionUser != null
          ? Map<String, dynamic>.from(sessionUser)
          : Map<String, dynamic>.from(widget.user);
      _bust = DateTime.now().millisecondsSinceEpoch;
    });
  }

  String _joinUrl(String base, String path) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path.substring(1) : path;
    return '$b/$p';
  }

  String? _profileUrl(Map<String, dynamic> u) {
    final p = u["profileImage"];
    if (p == null) return null;
    final s = p.toString().trim();
    if (s.isEmpty) return null;
    final clean = _joinUrl(widget.baseUrl, s);
    return "$clean?t=$_bust";
  }

  Future<void> _logout(BuildContext context) async {
    Navigator.of(context).pop(); // أغلق الـ Drawer
    await SessionService.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  // ✅ دالة مساعدة لفتح الصفحات
  void _navTo(Widget page) async {
    Navigator.pop(context); // أغلق الـ Drawer أولاً
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    // تحديث البيانات عند العودة
    await widget.onRefreshUser();
    await _loadUser();
  }

  void _showSnack(String msg) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final u = _user ?? widget.user;
    final role = (u["role"] ?? "client").toString().trim().toLowerCase();
    final name = (u["name"] ?? "User").toString();
    final url = _profileUrl(u);

    final isClient = role == "client";
    final isContractor = role == "contractor";

    return Drawer(
      backgroundColor: const Color(0xFF0F261F),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Header =====
            InkWell(
              onTap: () async {
                _navTo(ProfileScreen(
                  user: u,
                  baseUrl: widget.baseUrl,
                  onRefreshUser: widget.onRefreshUser,
                ));
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                width: double.infinity,
                color: Colors.white.withOpacity(0.03),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white12,
                      backgroundImage: url != null ? NetworkImage(url) : null,
                      child: url == null
                          ? const Icon(Icons.person,
                              size: 32, color: Colors.white70)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role.toUpperCase(),
                      style: TextStyle(
                        color: const Color(0xFF9EE7B7).withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ===== Menu Items =====
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _item(
                    Icons.person_outline,
                    "My Profile",
                    () => _navTo(ProfileScreen(
                      user: u,
                      baseUrl: widget.baseUrl,
                      onRefreshUser: widget.onRefreshUser,
                    )),
                  ),
                  const Divider(color: Colors.white10, height: 20),

                  if (isClient) ...[
                    _item(
                      Icons.add_circle_outline,
                      "New Project",
                      () async {
                        Navigator.pop(context); // Close drawer
                        // Show BottomSheet for Create Project
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => DraggableScrollableSheet(
                            initialChildSize: 0.92,
                            minChildSize: 0.7,
                            maxChildSize: 0.98,
                            builder: (_, sc) =>
                                CreateProjectFlow(scrollController: sc),
                          ),
                        );
                        // Refresh after creation
                        await widget.onRefreshUser();
                      },
                    ),
                    _item(
                      Icons.folder_open_outlined,
                      "My Projects",
                      () => _navTo(const MyProjectsPage()),
                    ),
                    _item(
                      Icons.engineering_outlined,
                      "Contractors",
                      () => _navTo(const ContractorsPage()),
                    ),
                    _item(
                      Icons.description_outlined,
                      "Contracts",
                      () => _navTo(const ContractsPage()),
                    ),
                  ],

                  if (isContractor) ...[
                    _item(
                      Icons.work_outline,
                      "Available Projects",
                      () => _showSnack("Use Home screen for available projects"),
                    ),
                    _item(
                      Icons.assignment_outlined,
                      "My Offers",
                      () => _navTo( const MyOffersPage()),
                    ),
                    _item(
                      Icons.description_outlined,
                      "Contracts",
                      () => _navTo(const MyContractsPage()),
                    ),
                  ],
                ],
              ),
            ),

            // ===== Footer =====
            const Divider(color: Colors.white10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: _item(
                Icons.logout_rounded,
                "Logout",
                () => _logout(context),
                color: Colors.redAccent,
                bgColor: Colors.redAccent.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, String title, VoidCallback onTap,
      {Color? color, Color? bgColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.white70, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        hoverColor: Colors.white.withOpacity(0.05),
      ),
    );
  }
}
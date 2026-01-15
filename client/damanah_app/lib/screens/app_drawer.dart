import 'package:flutter/material.dart';
import '../services/session_service.dart';
import 'profile_screen.dart';
import 'role_selection_screen.dart'; // ✅ بدل LoginScreen

class AppDrawer extends StatefulWidget {
  final Map<String, dynamic> user; // fallback فقط
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

      // ✅ اكسر كاش الصورة
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
    return "$clean?t=$_bust"; // ✅ cache bust
  }

  Future<void> _logout(BuildContext context) async {
    // ✅ سكّر الـ Drawer أولاً (اختياري بس ممتاز)
    Navigator.of(context).pop();

    await SessionService.clear();
    if (!context.mounted) return;

    // ✅ امسح كل الستاك وارجع للبداية (RoleSelection)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
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
          children: [
            ListTile(
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white12,
                backgroundImage: url != null ? NetworkImage(url) : null,
                child: url == null
                    ? const Icon(Icons.person, color: Colors.white70)
                    : null,
              ),
              title: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                role.toUpperCase(),
                style: const TextStyle(color: Colors.white70),
              ),
              onTap: () async {
                Navigator.pop(context);

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      user: u,
                      baseUrl: widget.baseUrl,
                      onRefreshUser: widget.onRefreshUser,
                    ),
                  ),
                );

                // ✅ بعد الرجوع: حدث session + drawer
                await widget.onRefreshUser();
                await _loadUser();
              },
            ),

            const Divider(color: Colors.white12),

            _item(Icons.person, "Profile", () async {
              Navigator.pop(context);

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    user: u,
                    baseUrl: widget.baseUrl,
                    onRefreshUser: widget.onRefreshUser,
                  ),
                ),
              );

              await widget.onRefreshUser();
              await _loadUser();
            }),

            if (isClient) ...[
              _item(Icons.add_box, "New Project", () {}),
              _item(Icons.folder, "My Projects", () {}),
              _item(Icons.description, "Contracts", () {}),
              _item(Icons.people, "Contractors", () {}),
            ],

            if (isContractor) ...[
              _item(Icons.work, "Available Projects", () {}),
              _item(Icons.assignment, "My Offers", () {}),
              _item(Icons.description, "Contracts", () {}),
            ],

            const Spacer(),
            const Divider(color: Colors.white12),

            _item(
              Icons.logout,
              "Logout",
              () => _logout(context),
              color: Colors.redAccent,
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white70),
      title: Text(title, style: TextStyle(color: color ?? Colors.white)),
      onTap: onTap,
    );
  }
}

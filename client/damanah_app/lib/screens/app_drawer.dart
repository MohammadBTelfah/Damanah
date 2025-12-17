import 'package:flutter/material.dart';
import '../services/session_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class AppDrawer extends StatelessWidget {
  final Map<String, dynamic> user;
  final String baseUrl;

  const AppDrawer({super.key, required this.user, required this.baseUrl});

  Future<void> _logout(BuildContext context) async {
    await SessionService.clear();
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(role: user["role"] ?? "client"),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = (user["role"] ?? "client").toString();
    final name = (user["name"] ?? "User").toString();
    final profileImage = user["profileImage"];

    final String? profileUrl =
        (profileImage != null && profileImage.toString().isNotEmpty)
            ? "$baseUrl/${profileImage.toString()}"
            : null;

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
                backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                child: profileUrl == null
                    ? const Icon(Icons.person, color: Colors.white70)
                    : null,
              ),
              title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: Text(role.toUpperCase(), style: const TextStyle(color: Colors.white70)),
              onTap: () async {
                Navigator.pop(context);

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(user: user, baseUrl: baseUrl),
                  ),
                );

                // ✅ بعد الرجوع: لا شيء هون لأنه الـ Home هو اللي بعمل _loadUser()
              },
            ),

            const Divider(color: Colors.white12),

            _item(Icons.person, "Profile", () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(user: user, baseUrl: baseUrl),
                ),
              );
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

            _item(Icons.logout, "Logout", () => _logout(context), color: Colors.redAccent),
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

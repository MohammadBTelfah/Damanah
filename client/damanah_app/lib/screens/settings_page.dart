import 'package:flutter/material.dart';
import '../services/session_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1814),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle("Account"),
          _tile(
            icon: Icons.person_outline,
            title: "Edit Profile",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Edit Profile (TODO)")),
              );
            },
          ),
          _tile(
            icon: Icons.lock_outline,
            title: "Change Password",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Change Password (TODO)")),
              );
            },
          ),

          const SizedBox(height: 14),
          _sectionTitle("Notifications"),
          _tile(
            icon: Icons.notifications_none,
            title: "Notification Preferences",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Notification settings (TODO)")),
              );
            },
          ),

          const SizedBox(height: 14),
          _sectionTitle("App"),
          _tile(
            icon: Icons.language,
            title: "Language",
            subtitle: "Arabic / English",
            onTap: () {},
          ),
          _tile(
            icon: Icons.info_outline,
            title: "About",
            onTap: () {},
          ),

          const SizedBox(height: 14),
          _sectionTitle("Security"),
          _tile(
            icon: Icons.logout,
            title: "Logout",
            onTap: () async {
              await SessionService.clear();
              if (context.mounted) {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        t,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F261F).withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style:
                            const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

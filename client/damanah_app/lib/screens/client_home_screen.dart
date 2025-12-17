import 'package:flutter/material.dart';
import '../services/session_service.dart';
import 'app_drawer.dart';
import 'profile_screen.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? _user;

  static const String baseUrl = "http://10.0.2.2:5000";

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = await SessionService.getUser();
    if (mounted) setState(() => _user = u);
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0F261F);
    const cardColor = Color(0xFF0F261F);

    final name = (_user?["name"] ?? "User").toString();
    final profileImage = _user?["profileImage"];

    final String? profileUrl =
        (profileImage != null && profileImage.toString().isNotEmpty)
            ? "$baseUrl/${profileImage.toString()}"
            : null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,
      drawer: _user == null ? null : AppDrawer(user: _user!, baseUrl: baseUrl),

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: bgColor,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white60,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: 'Projects'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        onTap: (index) async {
          if (index == 3 && _user != null) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(user: _user!, baseUrl: baseUrl),
              ),
            );
            await _loadUser(); // ✅ هي اللي بتحل رجوع البيانات القديمة
          }
        },
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white24,
                      backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                      child: profileUrl == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Home',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Text(
                "Welcome back, $name",
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 24),

              const Text(
                "Quick Actions",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
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

              const Text(
                "Project Offers",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
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
                          Text("Offer from BuildRight", style: TextStyle(color: Colors.white70, fontSize: 13)),
                          SizedBox(height: 6),
                          Text("Kitchen Remodel",
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text("View offer details", style: TextStyle(color: Colors.white54, fontSize: 13)),
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
                      child: const Icon(Icons.kitchen_outlined, color: Colors.white, size: 32),
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
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

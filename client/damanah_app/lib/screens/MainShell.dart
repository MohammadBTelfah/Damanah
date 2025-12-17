import 'package:flutter/material.dart';
import '../services/session_service.dart';
import 'client_home_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
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

  Future<void> _openProfile() async {
    if (_user == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          user: _user!,
          baseUrl: baseUrl,
          onRefreshUser: _loadUser,
        ),
      ),
    );

    await _loadUser();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ClientHomeScreen(
        user: _user,
        baseUrl: baseUrl,
        onRefreshUser: _loadUser,
        onOpenProfile: _openProfile,
      ),
      const _Placeholder(title: "Projects"),
      const _Placeholder(title: "Messages"),
      const _Placeholder(title: "Profile"),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F261F),
      body: IndexedStack(index: _index, children: pages),

      // ✅ منع الوميض/التضوية عند الضغط على عناصر البار
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory, // ❌ لا splash
          highlightColor: Colors.transparent,    // ❌ لا highlight
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF0F261F),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white60,
          currentIndex: _index,
          onTap: (i) async {
            if (i == 3) {
              await _openProfile(); // ✅ يفتح شاشة البروفايل بدون ما يغير التاب
              return;
            }
            setState(() => _index = i);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              label: "Projects",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: "Messages",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Text(
          "Coming Soon",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

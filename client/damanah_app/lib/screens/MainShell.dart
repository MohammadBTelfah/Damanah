import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../config/api_config.dart';

import 'client_home_screen.dart';
import 'profile_screen.dart';
import 'contractor_home_screen.dart';
import 'contractor_projects_page.dart';
import 'contractor_notifications_page.dart';
import 'notifications_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  Map<String, dynamic>? _user;

  String get baseUrl => ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = await SessionService.getUser();
    if (!mounted) return;
    setState(() => _user = u);
  }

  void _goToProfileTab() {
    setState(() => _index = 3);
  }

  @override
  Widget build(BuildContext context) {
    final role = (_user?["role"] ?? "client").toString().toLowerCase().trim();

    final home = role == "contractor"
        ? ContractorHomeScreen(
            user: _user,
            baseUrl: baseUrl,
            onRefreshUser: _loadUser,
          )
        : ClientHomeScreen(
            user: _user,
            baseUrl: baseUrl,
            onRefreshUser: _loadUser,
            onOpenProfile: _goToProfileTab,
          );

    final projectsPage =
        role == "contractor" ? const ContractorProjectsPage() : const _Placeholder(title: "Projects");

    final messagesPage =
        role == "contractor" ? const ContractorNotificationsPage() : const NotificationsPage();

    final pages = <Widget>[
      home,
      projectsPage,
      messagesPage,
      if (_user != null)
        ProfileScreen(
          user: _user!,
          baseUrl: baseUrl,
          isRoot: true,
          onRefreshUser: _loadUser,
        )
      else
        const _LoadingPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F261F),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF0F261F),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white60,
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), label: "Projects"),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "Messages"),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
          ],
        ),
      ),
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Text(
          "$title (Coming Soon)",
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

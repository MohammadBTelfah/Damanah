import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../config/api_config.dart';

// ✅ استدعاء الصفحات
import 'client_home_screen.dart';
import 'contractor_home_screen.dart';
import 'profile_screen.dart';
import 'my_projects_page.dart';
import 'contractors_page.dart';
import 'my_offers_page.dart';
import 'contractor_stats_pages.dart'; // فيها MyWorksPage

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
    // بما أن ترتيب البروفايل هو الأخير دائماً (رقم 3)
    setState(() => _index = 3);
  }

  @override
  Widget build(BuildContext context) {
    final role = (_user?["role"] ?? "client").toString().toLowerCase().trim();
    final isContractor = role == "contractor";

    // ====================================================
    // 🏗️ فصل القوائم (Shells) بناءً على الدور
    // ====================================================

    List<Widget> pages;
    List<NavigationDestination> destinations;

    if (isContractor) {
      // 👷‍♂️ إعدادات المقاول (Contractor Shell)
      pages = [
        ContractorHomeScreen(
          user: _user,
          baseUrl: baseUrl,
          onRefreshUser: _loadUser,
        ),
        const MyWorksPage(),
        const MyOffersPage(), // صفحة العروض المقدمة
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

      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view_rounded),
          label: "Dashboard",
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment_rounded),
          label: "Works",
        ),
        NavigationDestination(
          icon: Icon(Icons.local_offer_outlined),
          selectedIcon: Icon(Icons.local_offer_rounded),
          label: "Offers",
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person_rounded),
          label: "Profile",
        ),
      ];
    } else {
      // 👤 إعدادات العميل (Client Shell)
      pages = [
        ClientHomeScreen(
          user: _user,
          baseUrl: baseUrl,
          onRefreshUser: _loadUser,
          onOpenProfile: _goToProfileTab,
        ),
        const MyProjectsPage(), // صفحة مشاريع العميل
        const ContractorsPage(), // صفحة البحث عن مقاولين
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

      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: "Home",
        ),
        NavigationDestination(
          icon: Icon(Icons.folder_copy_outlined),
          selectedIcon: Icon(Icons.folder_copy_rounded),
          label: "Projects",
        ),
        NavigationDestination(
          icon: Icon(Icons.engineering_outlined),
          selectedIcon: Icon(Icons.engineering_rounded),
          label: "Contractors",
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person_rounded),
          label: "Profile",
        ),
      ];
    }

    // ====================================================

    return Scaffold(
      backgroundColor: const Color(0xFF0F261F),

      // ✅ عرض الصفحة المناسبة حسب الدور والفهرس
      body: IndexedStack(index: _index, children: pages),

      // ✅ عرض البار السفلي المناسب حسب الدور
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0F261F),
          indicatorColor: const Color(0xFF9EE7B7).withOpacity(0.2),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: Color(0xFF9EE7B7),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              );
            }
            return const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFF9EE7B7), size: 26);
            }
            return const IconThemeData(color: Colors.white60, size: 24);
          }),
        ),
        child: NavigationBar(
          height: 70,
          elevation: 0,
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: destinations, // ✅ نمرر القائمة التي حددناها فوق
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
      child: Center(child: CircularProgressIndicator(color: Color(0xFF9EE7B7))),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 60,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              "$title\n(Coming Soon)",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

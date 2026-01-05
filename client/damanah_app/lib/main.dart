import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/MainShell.dart'; // ✅ أضفها

void main() {
  runApp(const DamanahApp());
}

class DamanahApp extends StatelessWidget {
  const DamanahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Damanah',

      home: const SplashScreen(),

      routes: {
        '/role': (context) => const RoleSelectionScreen(),
        '/main': (context) => const MainShell(), // ✅ أضفها
      },
    );
  }
}

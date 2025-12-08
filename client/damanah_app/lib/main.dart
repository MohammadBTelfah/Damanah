import 'package:damanah_app/screens/role_selection_screen.dart';
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

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
      // أول صفحة تشتغل
      home: const SplashScreen(),
      
      // مؤقتاً لما ينتهي السبلّاش نروح على صفحة بسيطة
      routes: {
        '/role': (context) => const RoleSelectionScreen(),
      },
    );
  }
}

// صفحة مؤقتة بس لنتأكد من السبلّاش
class TempHomeScreen extends StatelessWidget {
  const TempHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Temporary Home Screen',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

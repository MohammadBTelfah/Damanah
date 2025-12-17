import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // بعد ثانيتين انتقل للصفحة التالية (لاحقًا بتتغير للـ Login Page)
    Timer(const Duration(seconds: 2), () {
      Navigator.pushReplacementNamed(context, "/role");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F261F), // Deep Slate Green
      body: Center(
        child: Image.asset(
          "assets/images/logo.png",
          width: 200,
        ),
      ),
    );
  }
}

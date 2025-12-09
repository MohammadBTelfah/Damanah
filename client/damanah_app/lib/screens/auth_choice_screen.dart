import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'client_register_screen.dart'; // 👈 مهم

class AuthChoiceScreen extends StatelessWidget {
  final String role;

  const AuthChoiceScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final isClient = role == "client";

    return Scaffold(
      backgroundColor: const Color(0xFF0F261F),
      body: SafeArea(
        child: Column(
          children: [
            // ===== زر الرجوع =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54, width: 1),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ===== اللــوقــو بدون خلفية =====
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Center(
                child: Image.asset(
                  "assets/images/logo.png",
                  height: 90,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // ===== النصوص =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isClient ? "Welcome to Damanah" : "Welcome Contractor",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isClient
                        ? "Find the right professional for your home project."
                        : "Get matched with quality clients for your next project.",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ===== الأزرار =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  // Log in button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LoginScreen(role: role),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF16C79A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Log in",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Sign up button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        if (isClient) {
                          // 🧑‍💼 تسجيل العميل
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ClientRegisterScreen(),
                            ),
                          );
                        } else {
                          // 👷‍♂️ لاحقاً نعمل شاشة Register خاصة بالمقاول
                          // حالياً ممكن نوديه لنفس اللوجين أو نخليها TODO
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LoginScreen(role: role),
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.25),
                        ),
                        backgroundColor: Colors.white.withOpacity(0.06),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                      ),
                      child: const Text(
                        "Sign up",
                        style: TextStyle(
                          fontSize: 17,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

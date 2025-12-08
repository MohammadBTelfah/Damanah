import 'package:flutter/material.dart';
import 'auth_choice_screen.dart';


class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F261F), // Deep Slate Green
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ====== Top bar (Damanah + ? icon) ======
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Damanah",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 1.3),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: const Icon(
                        Icons.help_outline,
                        color: Colors.white,
                      ),
                      onPressed: () {
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 60),

              // ====== Big title ======
              const Text(
                "Verified Contractors for\nYour Dream Project",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const Spacer(),

              // ====== Subtitle ======
              const Text(
                "Accurate estimates, manage contracts, and track "
                "your construction project from start to finish.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 32),

// ====== Continue as Client ======
SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthChoiceScreen(role: "client"),
        ),
      );
    },
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 18),
      backgroundColor: const Color(0xFF16C79A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(40),
      ),
      elevation: 0,
    ),
    child: const Text(
      "Continue as Client",
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Colors.black,
      ),
    ),
  ),
),


              const SizedBox(height: 16),

// ====== Continue as Contractor ======
SizedBox(
  width: double.infinity,
  child: OutlinedButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthChoiceScreen(role: "contractor"),
        ),
      );
    },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                    backgroundColor: Colors.white.withValues(alpha: 0.07),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                  child: const Text(
                    "Continue as Contractor",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),


              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'new_password_screen.dart';

class TokenScreen extends StatefulWidget {
  final String role; // client / contractor
  const TokenScreen({super.key, required this.role});

  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  bool _isValidOtp(String s) {
    // ✅ 6 digits and not start with 0
    return RegExp(r'^[1-9]\d{5}$').hasMatch(s);
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0F261F);
    const inputFill = Color(0xFF1B3A35);
    const primaryButton = Color(0xFF8BE3B5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Enter OTP", style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                "Enter the 6-digit OTP you received in your email.",
                style: TextStyle(color: Colors.white.withOpacity(0.75)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _otpController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  counterText: "",
                  filled: true,
                  fillColor: inputFill,
                  hintText: "OTP (6 digits)",
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) {
                  final s = (v ?? "").trim();
                  if (s.isEmpty) return "OTP is required";
                  if (!_isValidOtp(s)) return "OTP must be 6 digits (no leading 0)";
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryButton,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;

                    final otp = _otpController.text.trim();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NewPasswordScreen(
                          role: widget.role,
                          otp: otp, // ✅ بدل token
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    "Next",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

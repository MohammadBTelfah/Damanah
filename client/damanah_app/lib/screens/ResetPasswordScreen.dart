import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String role; // 'client' or 'contractor'
  const ResetPasswordScreen({super.key, required this.role});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmController = TextEditingController();

  final _authService = AuthService();
  bool _loading = false;
  bool _showPass = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _otpController.dispose();
    _passController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white)),
          backgroundColor: c,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  bool _isValidOtp(String s) {
    // ✅ 6 digits and not start with 0
    return RegExp(r'^[1-9]\d{5}$').hasMatch(s);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final pass = _passController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pass != confirm) {
      _snack("Passwords do not match", Colors.red);
      return;
    }

    setState(() => _loading = true);
    try {
      final otp = _otpController.text.trim();
      final newPass = pass;

      if (widget.role == 'client') {
        await _authService.resetPasswordClient(
          otp: otp,
          newPassword: newPass,
        );
      } else {
        await _authService.resetPasswordContractor(
          otp: otp,
          newPassword: newPass,
        );
      }

      if (!mounted) return;
      _snack("Password reset successfully", Colors.green);
      Navigator.pop(context); // ارجع للـ login
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst("Exception: ", ""), Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        title: const Text(
          "Reset Password",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _otpController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  counterText: "",
                  filled: true,
                  fillColor: inputFill,
                  hintText: "Enter OTP (6 digits)",
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

              const SizedBox(height: 12),

              TextFormField(
                controller: _passController,
                style: const TextStyle(color: Colors.white),
                obscureText: !_showPass,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: inputFill,
                  hintText: "New password",
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _showPass = !_showPass),
                    icon: Icon(
                      _showPass ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white70,
                    ),
                  ),
                ),
                validator: (v) {
                  final s = (v ?? "").trim();
                  if (s.isEmpty) return "Password required";
                  if (s.length < 8) return "At least 8 characters";
                  if (!s.contains('@')) return "Must include @";
                  return null;
                },
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _confirmController,
                style: const TextStyle(color: Colors.white),
                obscureText: !_showConfirm,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: inputFill,
                  hintText: "Confirm new password",
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _showConfirm = !_showConfirm),
                    icon: Icon(
                      _showConfirm ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white70,
                    ),
                  ),
                ),
                validator: (v) {
                  final s = (v ?? "").trim();
                  if (s.isEmpty) return "Confirm password";
                  return null;
                },
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryButton,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          "Reset Password",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

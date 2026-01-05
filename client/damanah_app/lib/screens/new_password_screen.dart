import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class NewPasswordScreen extends StatefulWidget {
  final String role;
  final String otp;

  const NewPasswordScreen({
    super.key,
    required this.role,
    required this.otp,
  });

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passController = TextEditingController();
  final _confirmController = TextEditingController();

  final _authService = AuthService();

  bool _isLoading = false;
  bool _showPass = false;
  bool _showConfirm = false;

  @override
  void dispose() {
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

  bool _isValidPassword(String v) {
    // حسب طلبك: لازم يحتوي @ وطويل
    return v.length >= 8 && v.contains('@');
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;

    final pass = _passController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pass != confirm) {
      _snack("Passwords do not match", Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (widget.role == 'client') {
        await _authService.resetPasswordClient(
          otp: widget.otp,
          newPassword: pass,
        );
      } else {
        await _authService.resetPasswordContractor(
          otp: widget.otp,
          newPassword: pass,
        );
      }

      if (!mounted) return;
      _snack("Password reset successfully", Colors.green);

      // رجّعه للـ login (pop مرتين)
      Navigator.pop(context); // يرجع لصفحة الـ OTP
      Navigator.pop(context); // يرجع للصفحة اللي قبلها (login/forgot)
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst("Exception: ", ""), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: const Text("New Password", style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 16),

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
                  if (v == null || v.trim().isEmpty) return "Password required";
                  if (!_isValidPassword(v.trim())) {
                    return "Min 8 chars and must include @";
                  }
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
                  if (v == null || v.trim().isEmpty) return "Confirm password";
                  return null;
                },
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _reset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryButton,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
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

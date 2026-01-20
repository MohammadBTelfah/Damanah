import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'scan_id_screen.dart'; // ✅ جديد
import 'verify_email_screen.dart'; // ✅ جديد

class ClientRegisterScreen extends StatefulWidget {
  const ClientRegisterScreen({super.key});

  @override
  State<ClientRegisterScreen> createState() => _ClientRegisterScreenState();
}

class _ClientRegisterScreenState extends State<ClientRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _fullNameController =
      TextEditingController(); // ✅ الاسم الإنجليزي من الهوية
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ✅ الرقم الوطني (قابل للتعديل)
  final _nationalIdController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _isLoading = false;

  // ✅ Show/Hide password
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // ---------- Profile Image ----------
  String? _profileImagePath;
  String? _profileImageName;
  // ----------------------------------

  // ---------- Identity Document (from Scan) ----------
  File? _identityImageFile; // ✅ ملف صورة الهوية من الكاميرا
  double? _nationalIdConfidence; // اختياري (حاليًا غالبًا null)
  // --------------------------------------

  @override
  void dispose() {
    _nameController.dispose();
    _fullNameController.dispose(); // ✅
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nationalIdController.dispose();
    super.dispose();
  }

  // SnackBar أعلى الشاشة
  void _showTopSnackBar(String message, Color color) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(top: 20, left: 16, right: 16),
      duration: const Duration(seconds: 2),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  Future<void> _pickProfileImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image, // ✅ صور فقط
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _profileImagePath = result.files.single.path!;
        _profileImageName = result.files.single.name;
      });
    }
  }

  // ✅ Scan ID (Camera + OCR)
  Future<void> _scanNationalId() async {
    final result = await Navigator.push<ScanIdResult>(
      context,
      MaterialPageRoute(builder: (_) => const ScanIdScreen()),
    );

    if (result != null) {
      setState(() {
        _identityImageFile = result.imageFile;
        _nationalIdController.text = result.nationalId;
        _fullNameController.text = result.fullName; // ✅ الاسم الإنجليزي
      });

      _showTopSnackBar("ID scanned successfully", Colors.green);
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    // ✅ التحقق من وجود صورة الهوية
    if (_identityImageFile == null) {
      _showTopSnackBar("Please scan your national ID", Colors.red);
      return;
    }

    // ✅ التحقق من وجود الرقم الوطني
    final nationalId = _nationalIdController.text.trim();
    if (nationalId.isEmpty) {
      _showTopSnackBar("National ID is required", Colors.red);
      return;
    }

    // ✅ التحقق من تطابق كلمة المرور
    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      _showTopSnackBar("Passwords do not match", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await _authService.registerClient(
        name: _nameController.text.trim(),
        fullName: _fullNameController.text.trim(), // ✅ جديد
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phone: _phoneController.text.trim(),

        // ✅ صورة الهوية من الـ Scan
        identityFilePath: _identityImageFile!.path,

        // ✅ الرقم الوطني
        nationalId: nationalId,

        // ✅ الصورة الشخصية (اختياري)
        profileImagePath: _profileImagePath,
      );

      debugPrint("Register response: $res");

      if (!mounted) return;

      // ✅ رسالة نجاح توضح الخطوة التالية
      _showTopSnackBar(
        "Account created successfully. Please verify your email.",
        Colors.green,
      );

      // ✅ الانتقال لصفحة التحقق بدلاً من Login
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(
              email: _emailController.text.trim(),
              role: 'client',
            ),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      _showTopSnackBar("Registration failed: ${e.toString()}", Colors.red);
      debugPrint("Register error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0F261F);
    const inputFill = Color(0xFF1B3A35);
    const primaryButton = Color(0xFF8BE3B5);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar بسيط
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(30),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    "Dhamanah",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.help_outline, color: Colors.white),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Create your account",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // ================= Profile Image (Centered) =================
                      const SizedBox(height: 8),

                      GestureDetector(
                        onTap: _pickProfileImage,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: Colors.white12,
                              backgroundImage: _profileImagePath != null
                                  ? FileImage(File(_profileImagePath!))
                                  : null,
                              child: _profileImagePath == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 48,
                                      color: Colors.white70,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "Tap to add profile photo (optional)",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 20),
                      // ============================================================

                      // Name (Display Name)
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputFill,
                          hintText: "Display name",
                          hintStyle: const TextStyle(color: Colors.white54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputFill,
                          hintText: "Email",
                          hintStyle: const TextStyle(color: Colors.white54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Email is required';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputFill,
                          hintText: "Phone number",
                          hintStyle: const TextStyle(color: Colors.white54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Phone is required';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // Password ✅ (عين + شروط)
                      TextFormField(
                        controller: _passwordController,
                        style: const TextStyle(color: Colors.white),
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputFill,
                          hintText: "Password",
                          hintStyle: const TextStyle(color: Colors.white54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Password is required';
                          if (v.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          if (!v.contains('@')) {
                            return 'Password must contain @';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // Confirm Password ✅ (عين + تطابق)
                      TextFormField(
                        controller: _confirmPasswordController,
                        style: const TextStyle(color: Colors.white),
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputFill,
                          hintText: "Confirm password",
                          hintStyle: const TextStyle(color: Colors.white54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Please confirm password';
                          if (v != _passwordController.text.trim()) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // ================= Scan National ID =================
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "National ID (scan by camera)",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      InkWell(
                        onTap: _scanNationalId,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: inputFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _identityImageFile == null
                                  ? Colors.white24
                                  : Colors.green,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.document_scanner_outlined,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _identityImageFile == null
                                      ? "Scan your national ID"
                                      : "ID scanned ✅ (tap to rescan)",
                                  style: TextStyle(
                                    color: _identityImageFile == null
                                        ? Colors.white54
                                        : Colors.white,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // National ID field (auto-filled + editable)
                      TextFormField(
                        controller: _nationalIdController,
                        style: const TextStyle(color: Colors.white),
                        readOnly: true, // ✅ غير قابل للتعديل
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputFill,
                          hintText: "National ID (auto-filled)",
                          hintStyle: const TextStyle(color: Colors.white54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "National ID is required";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // ✅✅✅ Full Name (from ID) تم النقل هنا ✅✅✅
                      TextFormField(
                        controller: _fullNameController,
                        style: const TextStyle(color: Colors.white),
                        readOnly: true, // ✅ غير قابل للتعديل
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputFill,
                          hintText: "Full Name (from ID)",
                          hintStyle: const TextStyle(color: Colors.white54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),

                      // =====================================================
                      const SizedBox(height: 24),

                      // Sign up button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: primaryButton,
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
                                  "Sign up",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Already have account
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(role: 'client'),
                            ),
                          );
                        },
                        child: const Text(
                          "Already have an account? Sign in",
                          style: TextStyle(
                            color: Colors.white70,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
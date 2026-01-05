import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'scan_id_screen.dart';

class ContractorRegisterScreen extends StatefulWidget {
  const ContractorRegisterScreen({super.key});

  @override
  State<ContractorRegisterScreen> createState() =>
      _ContractorRegisterScreenState();
}

class _ContractorRegisterScreenState extends State<ContractorRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController(); // Full name
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // الرقم الوطني (auto-filled + editable)
  final _nationalIdController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _isLoading = false;

  // 👁️ show/hide password
  bool _showPass = false;
  bool _showConfirm = false;

  // ---------- Profile Image ----------
  String? _profileImagePath;

  // ---------- Identity (from Scan) ----------
  File? _identityImageFile; // صورة الهوية من الكاميرا
  double? _nationalIdConfidence;

  // ---------- Contractor Document ----------
  String? _contractorFilePath;
  String? _contractorFileName;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nationalIdController.dispose();
    super.dispose();
  }

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

  bool _isValidPassword(String v) {
    // حسب طلبك: طويل + يحتوي @
    return v.length >= 8 && v.contains('@');
  }

  Future<void> _pickProfileImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _profileImagePath = result.files.single.path!);
    }
  }

  // Scan ID (Camera + OCR)
  Future<void> _scanNationalId() async {
    final result = await Navigator.push<ScanIdResult>(
      context,
      MaterialPageRoute(builder: (_) => const ScanIdScreen()),
    );

    if (result != null) {
      setState(() {
        _identityImageFile = result.imageFile;
        _nationalIdController.text = result.nationalId;
        _nationalIdConfidence = result.confidence;
      });

      _showTopSnackBar("ID scanned successfully", Colors.green);
    }
  }

  Future<void> _pickContractorDocument() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _contractorFilePath = result.files.single.path!;
        _contractorFileName = result.files.single.name;
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    // لازم scan للهوية
    if (_identityImageFile == null) {
      _showTopSnackBar("Please scan your national ID", Colors.red);
      return;
    }

    // لازم رقم وطني
    final nationalId = _nationalIdController.text.trim();
    if (nationalId.isEmpty) {
      _showTopSnackBar("National ID is required", Colors.red);
      return;
    }

    // لازم وثيقة المقاول
    if (_contractorFilePath == null) {
      _showTopSnackBar("Please upload contractor document", Colors.red);
      return;
    }

    final pass = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (pass != confirm) {
      _showTopSnackBar("Passwords do not match", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await _authService.registerContractor(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: pass,
        phone: _phoneController.text.trim(),

        // identityDocument من scan
        identityFilePath: _identityImageFile!.path,

        // contractor doc
        contractorFilePath: _contractorFilePath!,

        // national id
        nationalId: nationalId,
        nationalIdConfidence: _nationalIdConfidence,

        // optional
        profileImagePath: _profileImagePath,
      );

      debugPrint("Contractor register response: $res");

      if (!mounted) return;
      _showTopSnackBar(
        "Account created. Check your email to verify.",
        Colors.green,
      );

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(role: 'contractor'),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      _showTopSnackBar("Registration failed", Colors.red);
      debugPrint("Contractor register error: $e");
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
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
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
                  "Create contractor account",
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
                      // Profile Image
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
                          color: Colors.white.withAlpha(179),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Full name
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputFill,
                          hintText: "Full name",
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
                        validator: (value) => (value == null || value.isEmpty)
                            ? "Name is required"
                            : null,
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
                            return "Email is required";
                          }
                          if (!value.contains("@")) {
                            return "Enter a valid email";
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
                        validator: (value) => (value == null || value.isEmpty)
                            ? "Phone is required"
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Password (👁️)
                      TextFormField(
                        controller: _passwordController,
                        style: const TextStyle(color: Colors.white),
                        obscureText: !_showPass,
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
                            onPressed: () =>
                                setState(() => _showPass = !_showPass),
                            icon: Icon(
                              _showPass
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final v = (value ?? "").trim();
                          if (v.isEmpty) return "Password is required";
                          if (!_isValidPassword(v)) {
                            return "Min 8 chars and must include @";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Confirm password (👁️)
                      TextFormField(
                        controller: _confirmPasswordController,
                        style: const TextStyle(color: Colors.white),
                        obscureText: !_showConfirm,
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
                            onPressed: () => setState(
                                () => _showConfirm = !_showConfirm),
                            icon: Icon(
                              _showConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            (value == null || value.isEmpty)
                                ? "Please confirm password"
                                : null,
                      ),

                      const SizedBox(height: 16),

                      // Scan ID
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "National ID (scan by camera)",
                          style: TextStyle(
                            color: Colors.white.withAlpha(230),
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

                      // National ID
                      TextFormField(
                        controller: _nationalIdController,
                        style: const TextStyle(color: Colors.white),
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

                      // Contractor document upload
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Contractor document (license / record)",
                          style: TextStyle(
                            color: Colors.white.withAlpha(230),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickContractorDocument,
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
                              color: _contractorFilePath == null
                                  ? Colors.white24
                                  : Colors.green,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.upload_file_outlined,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _contractorFileName ??
                                      "Upload contractor document",
                                  style: TextStyle(
                                    color: _contractorFilePath == null
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
                              builder: (_) => const LoginScreen(role: 'contractor'),
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

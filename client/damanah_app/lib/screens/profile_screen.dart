import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../services/user_service.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String baseUrl;
  final bool isRoot;
  final Future<void> Function() onRefreshUser;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.baseUrl,
    this.isRoot = false,
    required this.onRefreshUser,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  late TextEditingController _name;
  late TextEditingController _phone;
  final _service = UserService();
  bool _saving = false;
  String? _pickedImagePath;
  // استخدام الـ Timestamp لضمان تحديث الصورة فوراً وتخطي الكاش
  int _imageBust = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: "");
    _phone = TextEditingController(text: "");
    _loadUser();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final sessionUser = await SessionService.getUser();
    final u = (sessionUser != null)
        ? Map<String, dynamic>.from(sessionUser)
        : Map<String, dynamic>.from(widget.user);

    if (!mounted) return;
    setState(() {
      _user = u;
      _name.text = (u["name"] ?? "").toString();
      _phone.text = (u["phone"] ?? "").toString();
      // تحديث الـ timestamp عند تحميل بيانات جديدة
      _imageBust = DateTime.now().millisecondsSinceEpoch;
    });
  }

  String _joinUrlSmart(String base, String path) {
    final t = path.trim();
    if (t.startsWith("http://") || t.startsWith("https://")) return t;
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = t.startsWith('/') ? t.substring(1) : t;
    return '$b/$p';
  }

  String? get _profileUrl {
    final u = _user;
    if (u == null) return null;
    
    final raw = (u["profileImage"] ?? "").toString().trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('http')) {
      return "$raw?t=$_imageBust";
    }

    final clean = _joinUrlSmart(widget.baseUrl, raw);
    return "$clean?t=$_imageBust";
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _pickedImagePath = result.files.single.path!);
    }
  }

  Future<void> _editField(String title, TextEditingController controller) async {
    final temp = TextEditingController(text: controller.text);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2C24),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: temp,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter value",
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.black12,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              controller.text = temp.text.trim();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9EE7B7),
              foregroundColor: Colors.black,
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      // 1. إرسال التحديث للسيرفر
      final res = await _service.updateMe(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        profileImagePath: _pickedImagePath,
      );

      // 2. استخراج البيانات المحدثة من الرد
      final updatedUser = Map<String, dynamic>.from(res["user"]);
      final token = await SessionService.getToken();
      if (token == null) throw Exception("No token found");

      // 3. حفظ البيانات الجديدة في الـ Session (مهم جداً للـ MainShell)
      await SessionService.saveSession(token: token, user: updatedUser);

      // 4. تحديث حالة الصفحة الحالية
      if (!mounted) return;
      setState(() {
        _user = updatedUser;
        _name.text = (updatedUser["name"] ?? "").toString();
        _phone.text = (updatedUser["phone"] ?? "").toString();
        _pickedImagePath = null;
        _imageBust = DateTime.now().millisecondsSinceEpoch;
      });

      // 5. استدعاء الدالة الممرة من الـ MainShell لتحديث البار السفلي والواجهات الأخرى
      await widget.onRefreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile updated successfully ✅"), 
            backgroundColor: Colors.green
          )
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgTop = Color(0xFF0E1814);
    
    final u = _user;
    if (u == null) return const Scaffold(backgroundColor: bgTop, body: Center(child: CircularProgressIndicator()));

    final role = (u["role"] ?? "").toString().toUpperCase();
    final email = (u["email"] ?? "").toString();
    final displayName = _name.text.trim().isEmpty ? "User" : _name.text.trim();

    return Scaffold(
      backgroundColor: bgTop,
      appBar: AppBar(
        backgroundColor: bgTop,
        elevation: 0,
        centerTitle: true,
        title: const Text("My Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _saving ? null : _saveProfile,
            icon: _saving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9EE7B7)))
              : const Icon(Icons.check, color: Color(0xFF9EE7B7)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ===== Avatar Section =====
            Center(
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF9EE7B7).withOpacity(0.5), width: 2),
                    ),
                    child: _Avatar(pickedPath: _pickedImagePath, networkUrl: _profileUrl),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF9EE7B7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            Text(
              displayName,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                role,
                style: const TextStyle(color: Color(0xFF9EE7B7), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),

            const SizedBox(height: 32),

            // ===== Info Cards =====
            _sectionTitle("Personal Information"),
            const SizedBox(height: 12),
            
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF15221D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  _tile(Icons.person_outline, "Name", displayName, onTap: () => _editField("Edit Name", _name)),
                  Divider(color: Colors.white.withOpacity(0.05), height: 1),
                  _tile(Icons.email_outlined, "Email", email, isEditable: false), 
                  Divider(color: Colors.white.withOpacity(0.05), height: 1),
                  _tile(Icons.phone_outlined, "Phone", _phone.text, onTap: () => _editField("Edit Phone", _phone)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _sectionTitle("Security"),
            const SizedBox(height: 12),
            
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF15221D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: ListTile(
                leading: const Icon(Icons.lock_outline, color: Colors.white70),
                title: const Text("Change Password", style: TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white30),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _tile(IconData icon, String title, String value, {VoidCallback? onTap, bool isEditable = true}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      subtitle: Text(value.isEmpty ? "-" : value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
      trailing: isEditable 
          ? const Icon(Icons.edit, size: 18, color: Color(0xFF9EE7B7)) 
          : null,
      onTap: onTap,
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? pickedPath;
  final String? networkUrl;

  const _Avatar({required this.pickedPath, required this.networkUrl});

  @override
  Widget build(BuildContext context) {
    const size = 110.0;
    ImageProvider? image;

    if (pickedPath != null) {
      image = FileImage(File(pickedPath!));
    } else if (networkUrl != null) {
      image = NetworkImage(networkUrl!);
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.white10,
      backgroundImage: image,
      child: image == null ? const Icon(Icons.person, size: 50, color: Colors.white30) : null,
    );
  }
}
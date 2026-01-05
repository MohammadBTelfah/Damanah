import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../services/user_service.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  /// ممكن تبعت user من أي شاشة (fallback فقط)
  final Map<String, dynamic> user;
  final String baseUrl;

  /// إذا كانت صفحة البروفايل "تاب" داخل BottomBar (Root) وما بدك السهم يطلعك برّا
  final bool isRoot;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.baseUrl,
    this.isRoot = false, required Future<void> Function() onRefreshUser,
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

  /// مهم لكسر كاش الصورة بعد التحديث
  int _imageBust = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();

    // مؤقتاً نهيّئ controllers فاضية وبنعبّيهم بعد تحميل اليوزر
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
    // ✅ خذ آخر نسخة من الجلسة
    final sessionUser = await SessionService.getUser();

    final u = (sessionUser != null)
        ? Map<String, dynamic>.from(sessionUser)
        : Map<String, dynamic>.from(widget.user);

    if (!mounted) return;

    setState(() {
      _user = u;
      _name.text = (u["name"] ?? "").toString();
      _phone.text = (u["phone"] ?? "").toString();
    });
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: c),
    );
  }

  String? get _profileUrl {
    final u = _user;
    if (u == null) return null;

    final p = u["profileImage"];
    if (p == null || p.toString().isEmpty) return null;

    // ✅ cache-bust
    return "${widget.baseUrl}/${p.toString()}?t=$_imageBust";
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
        backgroundColor: const Color(0xFF1B3A35),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: temp,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter value",
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              controller.text = temp.text.trim();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8BE3B5),
              foregroundColor: Colors.black,
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ✅ أهم دالة: تحفظ التعديل + تحدث Session + تحدث UI
  Future<void> _saveProfile() async {
    setState(() => _saving = true);

    try {
      final res = await _service.updateMe(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        profileImagePath: _pickedImagePath,
      );

      final updatedUser = Map<String, dynamic>.from(res["user"]);
      final token = await SessionService.getToken();
      if (token == null) throw Exception("No token");

      // ✅ احفظ آخر نسخة في الجهاز
      await SessionService.saveSession(token: token, user: updatedUser);

      if (!mounted) return;

      setState(() {
        _user = updatedUser;

        // ✅ حدّث الكنترولرز من السيرفر (عشان ما يصير - أو يرجع القديم)
        _name.text = (updatedUser["name"] ?? "").toString();
        _phone.text = (updatedUser["phone"] ?? "").toString();

        _pickedImagePath = null;

        // ✅ اكسر كاش الصورة
        _imageBust = DateTime.now().millisecondsSinceEpoch;
      });

      _snack("Profile updated", Colors.green);

      // ✅ إذا الشاشة من push (مش تاب root) رجّع user المحدث للي فتحها
      if (!widget.isRoot && Navigator.canPop(context)) {
        // اختياري: رجّعه بعد شوي عشان المستخدم يشوف الرسالة
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context, updatedUser);
          }
        });
      }
    } catch (e) {
      _snack("Update failed", Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F261F);
    const card = Color(0xFF1B3A35);

    final u = _user;
    if (u == null) {
      return const Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final role = (u["role"] ?? "").toString().toUpperCase();
    final email = (u["email"] ?? "").toString();

    final displayName = _name.text.trim().isEmpty ? "User" : _name.text.trim();

    ImageProvider? avatar;
    if (_pickedImagePath != null) {
      avatar = FileImage(File(_pickedImagePath!));
    } else if (_profileUrl != null) {
      avatar = NetworkImage(_profileUrl!);
    }

    return WillPopScope(
      onWillPop: () async {
        // ✅ إذا Root tab: ما تطلع برّا التطبيق
        if (widget.isRoot) return false;
        return true;
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white), // ✅ السهم أبيض
          automaticallyImplyLeading: !widget.isRoot, // ✅ إذا Root ما نعرض سهم
          title: const Text("Profile", style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: _saving ? null : _saveProfile,
              child: _saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.white12,
                      backgroundImage: avatar,
                      child: avatar == null
                          ? const Icon(
                              Icons.person,
                              color: Colors.white70,
                              size: 56,
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8BE3B5),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _editField("Edit name", _name),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),
              Text(role, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),

              _infoRow(card, "Email", email),
              _infoRow(
                card,
                "Phone",
                _phone.text,
                trailing: InkWell(
                  onTap: () => _editField("Edit phone", _phone),
                  child: const Icon(Icons.edit, color: Colors.white70, size: 18),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.white.withOpacity(0.20)),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: Colors.white.withOpacity(0.06),
                  ),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text(
                    "Change Password",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(Color bg, String label, String value, {Widget? trailing}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Text(
            value.trim().isEmpty ? "-" : value.trim(),
            style: const TextStyle(color: Colors.white),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing,
          ],
        ],
      ),
    );
  }
}

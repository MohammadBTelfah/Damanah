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
    });

    debugPrint("LOAD USER => $_user");
    debugPrint("LOAD profileImage => ${_user?["profileImage"]}");
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: c),
    );
  }

  /// ✅ join ذكي: إذا path أصلاً URL كامل ما يلمسه + يمنع مشكلة //
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

    final clean = _joinUrlSmart(widget.baseUrl, raw);
    final url = "$clean?t=$_imageBust"; // cache-bust

    debugPrint("PROFILE IMAGE RAW => $raw");
    debugPrint("PROFILE IMAGE URL => $url");

    return url;
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _pickedImagePath = result.files.single.path!);
      debugPrint("PICKED IMAGE PATH => $_pickedImagePath");
    }
  }

  Future<void> _editField(String title, TextEditingController controller) async {
    final temp = TextEditingController(text: controller.text);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF102A22),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: temp,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter value",
            hintStyle: const TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
            ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
      final res = await _service.updateMe(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        profileImagePath: _pickedImagePath,
      );

      final updatedUser = Map<String, dynamic>.from(res["user"]);
      debugPrint("UPDATED USER => $updatedUser");
      debugPrint("UPDATED profileImage => ${updatedUser["profileImage"]}");

      final token = await SessionService.getToken();
      if (token == null) throw Exception("No token");

      await SessionService.saveSession(token: token, user: updatedUser);

      if (!mounted) return;

      setState(() {
        _user = updatedUser;
        _name.text = (updatedUser["name"] ?? "").toString();
        _phone.text = (updatedUser["phone"] ?? "").toString();
        _pickedImagePath = null;
        _imageBust = DateTime.now().millisecondsSinceEpoch;
      });

      // ✅ اسحب آخر نسخة من session كمان (تأكيد)
      await _loadUser();

      _snack("Profile updated", Colors.green);

      // ✅ حدّث اليوزر في MainShell
      await widget.onRefreshUser();

      if (!widget.isRoot && Navigator.canPop(context)) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context, updatedUser);
          }
        });
      }
    } catch (e) {
      _snack(e.toString(), Colors.red);
      debugPrint("SAVE PROFILE ERROR => $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgTop = Color(0xFF0E221C);
    const bgBottom = Color(0xFF0A1511);
    const card = Color(0xFF0F261F);

    final u = _user;
    if (u == null) {
      return const Scaffold(
        backgroundColor: bgTop,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final role = (u["role"] ?? "").toString().toUpperCase();
    final email = (u["email"] ?? "").toString();
    final displayName = _name.text.trim().isEmpty ? "User" : _name.text.trim();

    return WillPopScope(
      onWillPop: () async => !widget.isRoot,
      child: Scaffold(
        backgroundColor: bgTop,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          automaticallyImplyLeading: !widget.isRoot,
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
                  : const Text(
                      "Save",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bgTop, bgBottom],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                decoration: BoxDecoration(
                  color: card.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: _Avatar(
                            pickedPath: _pickedImagePath,
                            networkUrl: _profileUrl,
                          ),
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8BE3B5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
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
                    Text(
                      role.isEmpty ? "CLIENT" : role,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: card.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Account",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _infoRow("Email", email),
                    const SizedBox(height: 10),
                    _infoRow(
                      "Phone",
                      _phone.text,
                      trailing: InkWell(
                        onTap: () => _editField("Edit phone", _phone),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
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
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Widget? trailing}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Flexible(
            child: Text(
              value.trim().isEmpty ? "-" : value.trim(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? pickedPath;
  final String? networkUrl;

  const _Avatar({required this.pickedPath, required this.networkUrl});

  @override
  Widget build(BuildContext context) {
    const size = 104.0;

    Widget content;

    if (pickedPath != null) {
      content = Image.file(File(pickedPath!), fit: BoxFit.cover);
    } else if (networkUrl != null) {
      content = Image.network(
        networkUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, err, __) {
          debugPrint("IMAGE LOAD ERROR => $err");
          debugPrint("IMAGE URL => $networkUrl");
          return const Center(
            child: Icon(Icons.person, color: Colors.white70, size: 54),
          );
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    } else {
      content = const Center(
        child: Icon(Icons.person, color: Colors.white70, size: 54),
      );
    }

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white10,
        border: Border.all(color: Colors.white.withOpacity(0.10), width: 2),
      ),
      child: ClipOval(child: content),
    );
  }
}

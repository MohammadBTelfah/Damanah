import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../services/project_service.dart';

class ContractorWorkDetailsPage extends StatefulWidget {
  final Map<String, dynamic> project;

  const ContractorWorkDetailsPage({super.key, required this.project});

  @override
  State<ContractorWorkDetailsPage> createState() =>
      _ContractorWorkDetailsPageState();
}

class _ContractorWorkDetailsPageState extends State<ContractorWorkDetailsPage> {
  final ProjectService _projectService = ProjectService();

  late String _currentStatus;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.project['status'] ?? "in_progress";
  }

  // ✅ Fixed: Resolving Profile Image URL using project settings
  String? get _profileUrl {
    final owner = widget.project['owner'];
    if (owner == null || owner is! Map) return null;

    // 1. تنظيف المسار القادم من السيرفر
    String rawPath = (owner["profileImage"] ?? "").toString().trim();
    if (rawPath.isEmpty) return null;

    // 2. تحويل أي مائل خلفي إلى مائل أمامي (Windows Fix)
    String cleanPath = rawPath.replaceAll('\\', '/');
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    // 3. ✅ الحل الجوهري: إضافة كلمة uploads/ للمسار يدوياً
    // لأن السيرفر يخدم الملفات عبر app.use('/uploads', express.static('uploads'))
    final String finalPath = cleanPath.contains('uploads/')
        ? cleanPath
        : "uploads/$cleanPath";

    // 4. دمج الرابط باستخدام ApiConfig.join لضمان الحصول على IP الكمبيوتر الصحيح
    final fullUrl = ApiConfig.join(finalPath);

    // 5. إضافة رقم عشوائي لمنع مشاكل الكاش
    final bust = DateTime.now().millisecondsSinceEpoch;

    return "$fullUrl?t=$bust";
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return Colors.blueAccent;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ✅ Fixed: Calling updateProjectStatus using correct Named Parameters
  Future<void> _changeStatus(String? newStatus) async {
    if (newStatus == null || newStatus == _currentStatus) return;

    setState(() => _isUpdating = true);

    final projectId = (widget.project['_id'] ?? widget.project['id'])
        .toString();

    try {
      // ✅ الاستدعاء الصحيح للوسائط المسماة
      await _projectService.updateProjectStatus(
        projectId: projectId,
        newStatus: newStatus,
      );

      setState(() {
        _currentStatus = newStatus;
        _isUpdating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Status updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Update failed: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchUri(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $uri");
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final title = project['title'] ?? "Untitled Project";
    final description = project['description'] ?? "No description provided.";
    final location = project['location'] ?? "Unknown";
    final area = project['area']?.toString() ?? "-";
    final floors = project['floors']?.toString() ?? "-";

    final estimation = project['estimation'];
    final totalCost = (estimation is Map)
        ? estimation['totalCost']?.toString()
        : "0";
    final currency = (estimation is Map)
        ? (estimation['currency'] ?? "JOD")
        : "JOD";

    List<dynamic> materialsList = [];
    if (estimation is Map && estimation['items'] is List) {
      materialsList = estimation['items'];
    }

    final owner = project['owner'];
    final clientName = (owner is Map) ? (owner['name'] ?? "Client") : "Unknown";
    final clientPhone = (owner is Map) ? (owner['phone'] ?? "") : "";

    final clientImageUrl = _profileUrl;

    return Scaffold(
      backgroundColor: const Color(0xFF0F261F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Project Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client Information Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1B3A35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white10,
                        child: ClipOval(
                          child: clientImageUrl != null
                              ? Image.network(
                                  clientImageUrl,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.person,
                                        size: 35,
                                        color: Colors.white70,
                                      ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 35,
                                  color: Colors.white70,
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clientName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Project Owner (Client)",
                              style: TextStyle(
                                color: Color(0xFF9EE7B7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.call,
                          label: "Call",
                          color: const Color(0xFF4CAF50),
                          onTap: () {
                            if (clientPhone.isNotEmpty)
                              _launchUri(Uri.parse("tel:$clientPhone"));
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.chat,
                          label: "WhatsApp",
                          color: const Color(0xFF25D366),
                          onTap: () {
                            if (clientPhone.isNotEmpty) {
                              var p = clientPhone.replaceAll(
                                RegExp(r'\s+'),
                                '',
                              );
                              _launchUri(Uri.parse("https://wa.me/$p"));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Project Main Information
            const Text(
              "Project Information",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1B3A35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(label: "Project Name", value: title),
                  const Divider(color: Colors.white10, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Status",
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      _isUpdating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  _currentStatus,
                                ).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getStatusColor(
                                    _currentStatus,
                                  ).withOpacity(0.5),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _currentStatus,
                                  dropdownColor: const Color(0xFF1B3A35),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: _getStatusColor(_currentStatus),
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: "in_progress",
                                      child: Text(
                                        "IN PROGRESS",
                                        style: TextStyle(
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: "completed",
                                      child: Text(
                                        "COMPLETED",
                                        style: TextStyle(color: Colors.green),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: "cancelled",
                                      child: Text(
                                        "CANCELLED",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                  onChanged: _changeStatus,
                                ),
                              ),
                            ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  _InfoRow(label: "Location", value: location),
                  const Divider(color: Colors.white10, height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoRow(label: "Area", value: "$area m²"),
                      ),
                      Expanded(
                        child: _InfoRow(label: "Floors", value: floors),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  const Text(
                    "Description",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Financial Details Section
            const Text(
              "Financial & Materials",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1B3A35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Estimated Cost",
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      Text(
                        "$totalCost $currency",
                        style: const TextStyle(
                          color: Color(0xFF9EE7B7),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  const Text(
                    "Required Materials",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  if (materialsList.isEmpty)
                    const Text(
                      "No materials specified.",
                      style: TextStyle(
                        color: Colors.white30,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: materialsList.map((item) {
                        String itemName = (item is Map)
                            ? (item['name'] ?? "Material")
                            : item.toString();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            itemName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

  // ✅ كود استخراج الصورة
String? get _profileUrl {
    final owner = widget.project['owner'];
    if (owner == null || owner is! Map) return null;

    String rawPath = (owner["profileImage"] ?? "").toString().trim();
    if (rawPath.isEmpty) return null;

    // ✅ إذا كان الرابط كاملاً من Cloudinary نرجعه كما هو فوراً
    if (rawPath.startsWith('http')) {
      return rawPath;
    }

    // ✅ للصور القديمة (التوافق مع السيرفر المحلي)
    String cleanPath = rawPath.replaceAll('\\', '/');
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    final String finalPath = cleanPath.contains('uploads/')
        ? cleanPath
        : "uploads/$cleanPath";

    return ApiConfig.join(finalPath);
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

  Future<void> _changeStatus(String? newStatus) async {
    if (newStatus == null || newStatus == _currentStatus) return;

    setState(() => _isUpdating = true);
    final projectId = (widget.project['_id'] ?? widget.project['id']).toString();

    try {
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
          const SnackBar(content: Text("Status updated!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isUpdating = false);
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
    
    // --- استخراج البيانات ---
    final title = project['title'] ?? "Untitled";
    final description = project['description'] ?? "No description.";
    final location = project['location'] ?? "Unknown";
    final area = project['area']?.toString() ?? "-";
    final floors = project['floors']?.toString() ?? "-";
    final buildingType = project['buildingType'] ?? "-";
    final finishingLevel = project['finishingLevel'] ?? "-";

    // استخراج تفاصيل المخطط
    String rooms = "-";
    String bathrooms = "-";
    if (project['planAnalysis'] != null && project['planAnalysis'] is Map) {
      rooms = project['planAnalysis']['rooms']?.toString() ?? "-";
      bathrooms = project['planAnalysis']['bathrooms']?.toString() ?? "-";
    }

    // البيانات المالية
    final estimation = project['estimation'];
    final totalCost = (estimation is Map) ? estimation['totalCost']?.toString() : "0";
    final currency = (estimation is Map) ? (estimation['currency'] ?? "JOD") : "JOD";
    
    List<dynamic> materialsList = [];
    if (estimation is Map && estimation['items'] is List) {
      materialsList = estimation['items'];
    }

    // بيانات العميل
    final owner = project['owner'];
    final clientName = (owner is Map) ? (owner['name'] ?? "Client") : "Unknown";
    final clientPhone = (owner is Map) ? (owner['phone'] ?? "") : "";
    final clientImageUrl = _profileUrl;

    return Scaffold(
      backgroundColor: const Color(0xFF0F261F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Project Details", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 إضافة العنوان هنا 🔥
            const Text(
              "Client Details",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // ===========================
            // 1. كارت العميل
            // ===========================
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
                        backgroundImage: clientImageUrl != null
                            ? NetworkImage(clientImageUrl)
                            : null,
                        child: clientImageUrl == null
                            ? const Icon(Icons.person, size: 35, color: Colors.white70)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(clientName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const Text("Project Owner", style: TextStyle(color: Color(0xFF9EE7B7), fontSize: 12)),
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
                          onTap: () { if (clientPhone.isNotEmpty) _launchUri(Uri.parse("tel:$clientPhone")); },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.chat,
                          label: "WhatsApp",
                          color: const Color(0xFF25D366),
                          onTap: () { if (clientPhone.isNotEmpty) _launchUri(Uri.parse("https://wa.me/${clientPhone.replaceAll(' ', '')}")); },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // ===========================
            // 2. تفاصيل المشروع
            // ===========================
            const Text("Project Information", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Status", style: TextStyle(color: Colors.white54, fontSize: 13)),
                      _isUpdating
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: _getStatusColor(_currentStatus).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _getStatusColor(_currentStatus).withOpacity(0.5)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _currentStatus,
                                  dropdownColor: const Color(0xFF1B3A35),
                                  icon: Icon(Icons.arrow_drop_down, color: _getStatusColor(_currentStatus)),
                                  items: const [
                                    DropdownMenuItem(value: "in_progress", child: Text("IN PROGRESS", style: TextStyle(color: Colors.blueAccent))),
                                    DropdownMenuItem(value: "completed", child: Text("COMPLETED", style: TextStyle(color: Colors.green))),
                                    DropdownMenuItem(value: "cancelled", child: Text("CANCELLED", style: TextStyle(color: Colors.red))),
                                  ],
                                  onChanged: _changeStatus,
                                ),
                              ),
                            ),
                    ],
                  ),
                  
                  const Divider(color: Colors.white24, height: 30),

                  _InfoRow(label: "Location", value: location),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _InfoRow(label: "Area", value: "$area m²")),
                      Expanded(child: _InfoRow(label: "Floors", value: floors)),
                    ],
                  ),

                  const Divider(color: Colors.white24, height: 30),

                  const Text("Construction Specs", style: TextStyle(color: Color(0xFF9EE7B7), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _InfoRow(label: "Building Type", value: buildingType)),
                      Expanded(child: _InfoRow(label: "Finishing Level", value: finishingLevel)),
                    ],
                  ),

                  const Divider(color: Colors.white24, height: 30),

                  const Text("Plan Details", style: TextStyle(color: Color(0xFF9EE7B7), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _InfoRow(label: "Rooms", value: rooms)),
                      Expanded(child: _InfoRow(label: "Bathrooms", value: bathrooms)),
                    ],
                  ),

                  const Divider(color: Colors.white24, height: 30),

                  const Text("Description", style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(description, style: const TextStyle(color: Colors.white, height: 1.5)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ===========================
            // 3. الأمور المالية
            // ===========================
            const Text("Financial & Materials", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
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
                      const Text("Estimated Cost", style: TextStyle(color: Colors.white54)),
                      Text("$totalCost $currency", style: const TextStyle(color: Color(0xFF9EE7B7), fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  
                  const Text("Materials", style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 12),
                  
                  if (materialsList.isEmpty)
                    const Text("No materials specified.", style: TextStyle(color: Colors.white30, fontStyle: FontStyle.italic))
                  else
                    Wrap(
                      spacing: 8, 
                      runSpacing: 8,
                      children: materialsList.map((item) {
                        String name = item is Map ? (item['name'] ?? "Material") : item.toString();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
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
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});
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
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
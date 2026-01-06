import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/project_service.dart';
import 'materials_screen.dart';

class UploadPlanScreen extends StatefulWidget {
  final String projectId;
  const UploadPlanScreen({super.key, required this.projectId});

  @override
  State<UploadPlanScreen> createState() => _UploadPlanScreenState();
}

class _UploadPlanScreenState extends State<UploadPlanScreen> {
  final _service = ProjectService();

  File? _file;
  bool _loading = false;

  Map<String, dynamic>? _planAnalysis;
  Map<String, dynamic>? _estimation;

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["pdf", "png", "jpg", "jpeg"],
    );
    if (res == null || res.files.single.path == null) return;
    setState(() => _file = File(res.files.single.path!));
  }

  Future<void> _upload() async {
    if (_file == null) return;

    setState(() => _loading = true);
    try {
      final data = await _service.uploadPlan(
        projectId: widget.projectId,
        filePath: _file!.path,
      );

      setState(() {
        _planAnalysis = (data["planAnalysis"] is Map)
            ? Map<String, dynamic>.from(data["planAnalysis"])
            : null;

        _estimation = (data["estimation"] is Map)
            ? Map<String, dynamic>.from(data["estimation"])
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0E1814);
    const card = Color(0xFF2F463D);
    const green = Color(0xFF9EE7B7);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text("Upload Plan"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Upload your house plan (PDF / Image)",
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _file == null
                            ? "No file selected"
                            : _file!.path.split("/").last,
                        style: const TextStyle(color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _pickFile,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: const Text("Choose"),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_file == null || _loading) ? null : _upload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Upload & Analyze"),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_planAnalysis != null)
            _InfoCard(
              title: "House Details",
              items: {
                "Total Area": "${_planAnalysis!["totalArea"] ?? "-"} m²",
                "Floors": "${_planAnalysis!["floors"] ?? "-"}",
                "Rooms": "${_planAnalysis!["rooms"] ?? "-"}",
                "Bathrooms": "${_planAnalysis!["bathrooms"] ?? "-"}",
              },
            ),

          if (_planAnalysis != null) const SizedBox(height: 12),

          if (_estimation != null)
            _InfoCard(
              title: "Initial Estimation",
              items: {
                "Estimated Total": "${_estimation!["total"] ?? "-"}",
              },
            ),

          const SizedBox(height: 16),

          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: (_planAnalysis == null)
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MaterialsScreen(projectId: widget.projectId),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text("Next: Materials"),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Map<String, String> items;
  const _InfoCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2F463D),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...items.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  Text(
                    e.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

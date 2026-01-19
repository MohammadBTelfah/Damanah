import 'package:flutter/material.dart';
import '../services/project_service.dart';
import 'contractor_work_details_page.dart'; // ✅ تأكد من استدعاء صفحة التفاصيل

// ==========================================
// 1. صفحة أعمالي (My Works)
// ==========================================
class MyWorksPage extends StatefulWidget {
  const MyWorksPage({super.key});

  @override
  State<MyWorksPage> createState() => _MyWorksPageState();
}

class _MyWorksPageState extends State<MyWorksPage> {
  final ProjectService _projectService = ProjectService();
  Future<List<dynamic>>? _worksFuture;

  @override
  void initState() {
    super.initState();
    // نقوم بتحديث القائمة في كل مرة نفتح الصفحة لضمان ظهور التعديلات الأخيرة
    _worksFuture = _projectService.getMyProjectsForContractor();
  }

  // دالة مساعدة لتحديد اللون بناءً على الحالة
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress': return Colors.blueAccent; // أزرق للجاري
      case 'completed': return Colors.green;       // أخضر للمكتمل
      case 'cancelled': return Colors.redAccent;   // ✅ أحمر للملغي
      case 'halted': return Colors.orange;         // برتقالي للمتوقف
      default: return const Color(0xFF9EE7B7);     // الافتراضي
    }
  }

  // دالة مساعدة لتنسيق النص
  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').toUpperCase();
  }

  AppBar _buildAppBar(String title) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F261F),
      appBar: _buildAppBar("My Active Works"),
      body: FutureBuilder<List<dynamic>>(
        future: _worksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF9EE7B7)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading works: ${snapshot.error}",
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final works = snapshot.data ?? [];

          if (works.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.engineering_outlined, size: 60, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  const Text(
                    "No active works yet.",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: works.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final work = works[index];
              
              final title = work['title'] ?? "Untitled Project";
              final ownerObj = work['owner'];
              final clientName = (ownerObj is Map) ? (ownerObj['name'] ?? "Unknown Client") : "Unknown Client";
              final status = work['status'] ?? "Active";
              
              // تحديد نسبة الإنجاز واللون
              double progress = 0.1;
              if (status == 'in_progress') progress = 0.5;
              if (status == 'completed') progress = 1.0;
              if (status == 'cancelled') progress = 0.0; // لا يوجد إنجاز للملغي

              // ✅ نستخدم الدالة الجديدة لتحديد اللون
              Color statusColor = _getStatusColor(status);

              return GestureDetector(
                onTap: () async {
                  // نستخدم await هنا لنقوم بتحديث القائمة عند العودة من صفحة التفاصيل
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContractorWorkDetailsPage(project: work),
                    ),
                  );
                  // تحديث البيانات بعد العودة (في حال غيرنا الحالة)
                  setState(() {
                    _worksFuture = _projectService.getMyProjectsForContractor();
                  });
                },
                child: _WorkCard(
                  title: title,
                  client: clientName,
                  progress: progress,
                  deadline: "TBD",
                  status: _formatStatus(status),
                  statusColor: statusColor, // ✅ نمرر اللون هنا
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _WorkCard extends StatelessWidget {
  final String title;
  final String client;
  final double progress;
  final String deadline;
  final String status;
  final Color statusColor; // ✅ متغير جديد للون

  const _WorkCard({
    required this.title,
    required this.client,
    required this.progress,
    required this.deadline,
    required this.status,
    required this.statusColor, // ✅ مطلوب
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  // ✅ الخلفية تأخذ لون الحالة بشفافية
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor, // ✅ النص يأخذ لون الحالة
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("Client: $client", style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white10,
                    color: statusColor, // ✅ شريط التقدم يأخذ لون الحالة
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text("${(progress * 100).toInt()}%", style: const TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../services/project_service.dart';
import '../services/contract_service.dart'; // نحتاجها للعقود لاحقاً

// ==========================================
// 1. صفحة أعمالي (My Works) - ✅ مربوطة بالـ API
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
    // استدعاء الـ API لجلب المشاريع المرتبطة بالمقاول
    _worksFuture = _projectService.getMyProjectsForContractor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F261F),
      appBar: _buildAppBar("My Active Works"),
      body: FutureBuilder<List<dynamic>>(
        future: _worksFuture,
        builder: (context, snapshot) {
          // 1. حالة التحميل
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF9EE7B7)));
          }

          // 2. حالة الخطأ
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading works: ${snapshot.error}",
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final works = snapshot.data ?? [];

          // 3. القائمة فارغة
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

          // 4. عرض القائمة الحقيقية
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: works.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final work = works[index];
              
              // استخراج البيانات (مع حماية من القيم الفارغة)
              final title = work['title'] ?? "Untitled Project";
              final ownerObj = work['owner']; // قد يكون Map أو String حسب الـ Populate
              final clientName = (ownerObj is Map) ? (ownerObj['name'] ?? "Unknown Client") : "Unknown Client";
              final status = work['status'] ?? "Active";
              
              // تحديد نسبة الإنجاز واللون بناءً على الحالة (افتراضي لأن الـ API لا يرسل نسبة)
              double progress = 0.0;
              Color statusColor = const Color(0xFF9EE7B7);
              
              if (status == 'in_progress') {
                progress = 0.5;
              } else if (status == 'completed') {
                progress = 1.0;
              } else {
                progress = 0.1;
                statusColor = Colors.orange;
              }

              return _WorkCard(
                title: title,
                client: clientName,
                progress: progress,
                deadline: "TBD", // التاريخ غير موجود في الرد الحالي، يمكن إضافته لاحقاً
                status: status,
                isWarning: status == 'draft' || status == 'open', // مثال
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
  final bool isWarning;

  const _WorkCard({
    required this.title,
    required this.client,
    required this.progress,
    required this.deadline,
    required this.status,
    this.isWarning = false,
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
                  color: isWarning ? Colors.orange.withOpacity(0.2) : const Color(0xFF9EE7B7).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isWarning ? Colors.orange : const Color(0xFF9EE7B7),
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
                    color: isWarning ? Colors.orange : const Color(0xFF9EE7B7),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text("${(progress * 100).toInt()}%", style: const TextStyle(color: Colors.white)),
            ],
          ),
          // تم إخفاء الموعد النهائي مؤقتاً لعدم وجوده في الـ API
          // const SizedBox(height: 12),
          // Row(
          //   children: [
          //     const Icon(Icons.calendar_today, size: 14, color: Colors.white54),
          //     const SizedBox(width: 6),
          //     Text("Deadline: $deadline", style: const TextStyle(color: Colors.white54, fontSize: 13)),
          //   ],
          // ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. صفحة العروض (Offers) - ثابتة حالياً
// ==========================================
class MyOffersPage extends StatelessWidget {
  const MyOffersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F261F),
      appBar: _buildAppBar("My Submitted Offers"),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined, size: 60, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            const Text("No offers found (Coming Soon).", style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. صفحة العقود (Contracts) - ثابتة حالياً
// ==========================================
class MyContractsPage extends StatelessWidget {
  const MyContractsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F261F),
      appBar: _buildAppBar("Active Contracts"),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 60, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            const Text("No contracts found (Coming Soon).", style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

// Helper for AppBars
AppBar _buildAppBar(String title) {
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    centerTitle: true,
    iconTheme: const IconThemeData(color: Colors.white),
  );
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:url_launcher/url_launcher.dart'; // ✅ تم إضافة المكتبة
import '../services/contract_service.dart';
import '../services/session_service.dart';

class ContractsPage extends StatefulWidget {
  const ContractsPage({super.key});

  @override
  State<ContractsPage> createState() => _ContractsPageState();
}

class _ContractsPageState extends State<ContractsPage>
    with SingleTickerProviderStateMixin {
  final _service = ContractService();
  late TabController _tabController;

  bool _loading = true;
  String? _myId;
  List<dynamic> _allContracts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await SessionService.getUser();
      _myId = user?["_id"] ?? user?["id"];

      final list = await _service.getMyContracts();
      setState(() => _allContracts = list);
    } catch (e) {
      debugPrint("Error loading contracts: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // تصفية القوائم بناءً على الـ status
    final activeList = _allContracts.where((c) {
      final s = (c["status"] ?? "").toString().toLowerCase();
      return s == "active" || s == "pending";
    }).toList();

    final historyList = _allContracts.where((c) {
      final s = (c["status"] ?? "").toString().toLowerCase();
      return s == "completed" || s == "cancelled";
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0E1814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1814),
        elevation: 0,
        centerTitle: true,
        title: const Text("My Contracts",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF9EE7B7),
          unselectedLabelColor: Colors.white54,
          indicatorColor: const Color(0xFF9EE7B7),
          tabs: const [
            Tab(text: "Active & Pending"),
            Tab(text: "History"),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF9EE7B7)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(activeList, "No active contracts"),
                _buildList(historyList, "No past contracts"),
              ],
            ),
    );
  }

  Widget _buildList(List<dynamic> list, String emptyMsg) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 60, color: Colors.white12),
            const SizedBox(height: 16),
            Text(emptyMsg, style: const TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _ContractCard(contract: list[index], myId: _myId);
      },
    );
  }
}

class _ContractCard extends StatelessWidget {
  final Map<String, dynamic> contract;
  final String? myId;

  const _ContractCard({required this.contract, required this.myId});

  // ✅ دالة جديدة لفتح رابط الـ PDF
  Future<void> _openContractPdf(BuildContext context) async {
    final String? pdfUrl = contract["contractFile"]; // الرابط من الباك إند

    if (pdfUrl != null && pdfUrl.isNotEmpty) {
      final Uri uri = Uri.parse(pdfUrl);
      
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Could not launch contract URL")),
            );
          }
        }
      } catch (e) {
        debugPrint("Error launching URL: $e");
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contract PDF not available yet")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. استخراج البيانات
    final project = contract["project"] ?? {};
    final projectTitle = project["title"] ?? "Untitled Project";

    // 2. معرفة الطرف الآخر
    final client = contract["client"] ?? {};
    final contractor = contract["contractor"] ?? {};
    
    // التحقق من الآيدي
    final clientId = client["_id"] ?? client["id"];
    final isMeClient = (clientId.toString() == myId.toString());

    final otherParty = isMeClient ? contractor : client;
    final otherRole = isMeClient ? "Contractor" : "Client";
    
    final otherName = otherParty["name"] ?? "Unknown User";
    
    // 3. البيانات المالية والزمنية
    final price = contract["agreedPrice"]?.toString() ?? "0";
    final startDate = contract["startDate"]?.toString().split("T").first ?? "-";
    final status = (contract["status"] ?? "active").toString().toUpperCase();

    // 4. تنسيق اللون حسب الحالة
    Color statusColor;
    switch (status.toLowerCase()) {
      case "active": statusColor = Colors.greenAccent; break;
      case "pending": statusColor = Colors.orangeAccent; break;
      case "completed": statusColor = Colors.blueAccent; break;
      case "cancelled": statusColor = Colors.redAccent; break;
      default: statusColor = Colors.white54;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF15221D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Project & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  projectTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          Divider(color: Colors.white.withOpacity(0.05), height: 1),
          const SizedBox(height: 12),

          // Body: Info Rows
          Row(
            children: [
              // Avatar for other party
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white10,
                child: const Icon(Icons.person, color: Colors.white60),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(otherName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    Text(otherRole, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ],
                ),
              ),
              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("$price JOD", style: const TextStyle(color: Color(0xFF9EE7B7), fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text("Start: $startDate", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          
          // Action Button
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: () => _openContractPdf(context), // ✅ استدعاء دالة فتح الرابط
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                foregroundColor: Colors.white70,
              ),
              child: const Text("View Contract PDF"), // ✅ تغيير النص ليكون أدق
            ),
          )
        ],
      ),
    );
  }
}
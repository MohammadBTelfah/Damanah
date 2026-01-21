import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ 1. إضافة المكتبة
import '../services/contract_service.dart';

class MyContractsPage extends StatefulWidget {
  const MyContractsPage({super.key});

  @override
  State<MyContractsPage> createState() => _MyContractsPageState();
}

class _MyContractsPageState extends State<MyContractsPage> {
  final ContractService _contractService = ContractService();
  Future<List<dynamic>>? _contractsFuture;

  @override
  void initState() {
    super.initState();
    _contractsFuture = _contractService.getMyContracts();
  }

  AppBar _buildAppBar(String title) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F261F),
      appBar: _buildAppBar("Active Contracts"),
      body: FutureBuilder<List<dynamic>>(
        future: _contractsFuture,
        builder: (context, snapshot) {
          // 1. Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF9EE7B7)));
          }

          // 2. Error
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Error loading contracts.\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }

          final contracts = snapshot.data ?? [];

          // 3. Empty
          if (contracts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined,
                      size: 60, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  const Text(
                    "No active contracts found.",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          // 4. List
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: contracts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final contract = contracts[index];

              // استخراج البيانات
              final projectObj = contract['project'];
              final projectTitle = (projectObj is Map)
                  ? projectObj['title']
                  : "Unknown Project";

              final clientObj = contract['client'];
              final clientName =
                  (clientObj is Map) ? clientObj['name'] : "Unknown Client";

              final price = contract['agreedPrice']?.toString() ?? "0";
              final status = contract['status'] ?? "Active";
              final startDateRaw = contract['startDate'] ?? "";
              
              // ✅ استخراج رابط ملف العقد
              final pdfUrl = contract['contractFile']; 

              String date = "";
              if (startDateRaw.length >= 10) {
                date = startDateRaw.substring(0, 10);
              }

              return _ContractCard(
                title: projectTitle.toString(),
                client: clientName.toString(),
                price: "$price JOD",
                date: date,
                status: status.toString(),
                pdfUrl: pdfUrl, // ✅ تمرير الرابط للبطاقة
              );
            },
          );
        },
      ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  final String title;
  final String client;
  final String price;
  final String date;
  final String status;
  final String? pdfUrl; // ✅ متغير الرابط

  const _ContractCard({
    required this.title,
    required this.client,
    required this.price,
    required this.date,
    required this.status,
    this.pdfUrl,
  });

  // ✅ دالة فتح الرابط
  Future<void> _openPdf(BuildContext context) async {
    if (pdfUrl != null && pdfUrl!.isNotEmpty) {
      final Uri uri = Uri.parse(pdfUrl!);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
           // محاولة إضافية للأندرويد
           try {
             await launchUrl(uri, mode: LaunchMode.externalApplication);
           } catch (e) {
             if (context.mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("Could not launch PDF")),
               );
             }
           }
        }
      } catch (e) {
        debugPrint("Error launching PDF: $e");
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PDF not available yet")),
      );
    }
  }

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF66BB6A).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.description,
                    color: Color(0xFF66BB6A), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Client: $client",
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Agreed Price",
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(price,
                      style: const TextStyle(
                          color: Color(0xFF9EE7B7), fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Start Date",
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(date,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          
          // ✅ إضافة الزر هنا
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: OutlinedButton.icon(
              onPressed: () => _openPdf(context),
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text("View Contract PDF"),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF9EE7B7),
                side: const BorderSide(color: Color(0xFF9EE7B7)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
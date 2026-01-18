import 'package:flutter/material.dart';
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
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            return const Center(child: CircularProgressIndicator(color: Color(0xFF9EE7B7)));
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
                  Icon(Icons.description_outlined, size: 60, color: Colors.white.withOpacity(0.2)),
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
              
              // استخراج البيانات مع الحماية من القيم الفارغة
              // ملاحظة: افترضنا أن الـ populate يعمل في الباك إند للمشروع والعميل
              final projectObj = contract['project'];
              final projectTitle = (projectObj is Map) ? projectObj['title'] : "Unknown Project";
              
              final clientObj = contract['client'];
              final clientName = (clientObj is Map) ? clientObj['name'] : "Unknown Client";

              final price = contract['agreedPrice']?.toString() ?? "0";
              final status = contract['status'] ?? "Active";
              final startDateRaw = contract['startDate'] ?? "";

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

  const _ContractCard({
    required this.title,
    required this.client,
    required this.price,
    required this.date,
    required this.status,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF66BB6A).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.description, color: Color(0xFF66BB6A), size: 24),
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
                        fontWeight: FontWeight.bold
                      ),
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
                  const Text("Agreed Price", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(price, style: const TextStyle(color: Color(0xFF9EE7B7), fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Start Date", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(date, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../services/project_service.dart';

class MyOffersPage extends StatefulWidget {
  const MyOffersPage({super.key});

  @override
  State<MyOffersPage> createState() => _MyOffersPageState();
}

class _MyOffersPageState extends State<MyOffersPage> {
  final ProjectService _projectService = ProjectService();
  Future<List<dynamic>>? _offersFuture;

  @override
  void initState() {
    super.initState();
    _offersFuture = _projectService.getMyOffers();
  }

  // دالة مساعدة لبناء الـ AppBar بنفس التصميم
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
      appBar: _buildAppBar("My Submitted Offers"),
      body: FutureBuilder<List<dynamic>>(
        future: _offersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF9EE7B7)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final offers = snapshot.data ?? [];

          if (offers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_offer_outlined, size: 60, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  const Text(
                    "You haven't submitted any offers yet.",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: offers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final offer = offers[index];
              
              final title = offer['projectTitle'] ?? "Unknown Project";
              final price = offer['price']?.toString() ?? "0";
              final status = offer['status'] ?? "pending";
              final dateRaw = offer['createdAt'] ?? "";
              
              String date = "";
              if (dateRaw.length >= 10) {
                date = dateRaw.substring(0, 10);
              }

              Color statusColor = Colors.orange;
              if (status == 'accepted') statusColor = const Color(0xFF9EE7B7);
              if (status == 'rejected') statusColor = Colors.redAccent;

              return _OfferCard(
                projectTitle: title,
                price: "$price JOD",
                date: date,
                status: status.toUpperCase(),
                statusColor: statusColor,
              );
            },
          );
        },
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final String projectTitle;
  final String price;
  final String date;
  final String status;
  final Color statusColor;

  const _OfferCard({
    required this.projectTitle,
    required this.price,
    required this.date,
    required this.status,
    required this.statusColor,
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_offer_outlined, color: Colors.white70),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  projectTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  price,
                  style: const TextStyle(
                    color: Color(0xFF9EE7B7),
                    fontWeight: FontWeight.w800,
                    fontSize: 15
                  )
                ),
                const SizedBox(height: 4),
                if (date.isNotEmpty)
                  Text(
                    date,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold
              ),
            ),
          ),
        ],
      ),
    );
  }
}
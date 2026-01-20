import 'package:flutter/material.dart';
import '../services/project_service.dart';
import '../config/api_config.dart'; // ✅ استيراد ملف الإعدادات

class ProjectDetailsPage extends StatefulWidget {
  final String projectId;
  const ProjectDetailsPage({super.key, required this.projectId});

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  final _service = ProjectService();

  bool _loading = true;
  bool _downloading = false;
  String? _error;
  Map<String, dynamic>? _data;

  Future<List<dynamic>>? _offersFuture;
  
  // ✅ متغير واحد للتحميل (سواء قبول أو رفض) لتجنب التعارض
  bool _processingOffer = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _service.getProjectById(widget.projectId);

      final project = (res["project"] is Map)
          ? Map<String, dynamic>.from(res["project"])
          : Map<String, dynamic>.from(res);

      setState(() => _data = project);

      if ((project["status"] ?? "open") == "open") {
        _offersFuture = _service.getProjectOffers(projectId: widget.projectId);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshOffers() async {
    setState(() {
      _offersFuture = _service.getProjectOffers(projectId: widget.projectId);
    });
  }

  Future<void> _downloadEstimateFile() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      await _service.downloadEstimateToFile(projectId: widget.projectId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text(
                "Estimate downloaded successfully!",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Download failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  // ====================== Smart URL Helper ======================
  String _toAbsoluteUrl(String? maybeUrl) {
    if (maybeUrl == null || maybeUrl.trim().isEmpty) return "";
    final v = maybeUrl.trim();
    if (v.startsWith("http")) return v;
    return ApiConfig.join(v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1814),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: const Text(
          "Project Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF9EE7B7)),
            )
          : _error != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF9EE7B7),
                  backgroundColor: const Color(0xFF1A2C24),
                  child: _buildContent(),
                ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 50, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9EE7B7),
            ),
            child: const Text("Retry", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final p = _data ?? {};
    final title = (p["title"] ?? "Untitled").toString();
    final status = (p["status"] ?? "open").toString().toLowerCase();

    final showOffers = status == "open";

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _statusChip(status),
          ],
        ),

        const SizedBox(height: 20),

        if (p["estimation"] != null || p["estimate"] != null)
          _buildDetailedEstimateCard(p)
        else
          _buildEmptyEstimateCard(),

        const SizedBox(height: 20),
        _buildInfoCard(p),
        const SizedBox(height: 20),

        if (p["planAnalysis"] != null)
          _buildEnhancedPlanAnalysisCard(p["planAnalysis"]),

        if (p["contractor"] != null) ...[
          const SizedBox(height: 20),
          _buildContractorCard(p),
        ],

        if (showOffers) ...[
          const SizedBox(height: 20),
          _buildOffersSection(),
        ],

        const SizedBox(height: 40),
      ],
    );
  }

  // ✅ كرت التحليل الهندسي الموحد
  Widget _buildEnhancedPlanAnalysisCard(dynamic paRaw) {
    final pa = (paRaw is Map) ? paRaw : {};
    final openings = pa["openings"] ?? {};
    final windows = openings["windows"] ?? {};
    final internalDoors = openings["internalDoors"] ?? {};
    final voids = openings["voids"] ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("ARCHITECTURE TAKEOFF (AI)"),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pill(Icons.crop_square, "${pa["totalArea"] ?? "--"} m²"),
              _pill(Icons.layers, "${pa["floors"] ?? "1"} Floors"),
              _pill(Icons.straighten,
                  "${pa["wallPerimeterLinear"] ?? pa["wallPerimeter"] ?? "--"} m Perimeter"),
              _pill(Icons.height,
                  "${pa["ceilingHeight"] ?? pa["ceilingHeightDefault"] ?? "3.0"} m Ceiling"),
              _pill(Icons.meeting_room_outlined, "${pa["rooms"] ?? "?"} Rooms"),
              _pill(Icons.bathtub_outlined, "${pa["bathrooms"] ?? "?"} Baths"),
              _pill(Icons.window,
                  "${windows["count"] ?? pa["windowsCount"] ?? "0"} Windows"),
              _pill(Icons.door_front_door,
                  "${internalDoors["count"] ?? pa["internalDoorsCount"] ?? "0"} Doors"),
              if (voids["totalVoidArea"] != null && voids["totalVoidArea"] > 0)
                _pill(Icons.grid_view_rounded,
                    "${voids["totalVoidArea"]} m² Voids",
                    color: const Color(0xFFFFCC80)),
            ],
          ),
          if (pa["notes"] != null && (pa["notes"] as List).isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text("AI NOTES",
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            ...(pa["notes"] as List).map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text("• $n",
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                )),
          ]
        ],
      ),
    );
  }

  Widget _buildDetailedEstimateCard(Map<String, dynamic> p) {
    final est = (p["estimation"] is Map)
        ? Map<String, dynamic>.from(p["estimation"])
        : (p["estimate"] is Map)
            ? Map<String, dynamic>.from(p["estimate"])
            : <String, dynamic>{};

    final total = est["totalCost"] ?? est["total"];
    final currency = (est["currency"] ?? "JOD").toString();
    final items = (est["items"] is List) ? List.from(est["items"]) : [];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B3A30), Color(0xFF0F261F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF9EE7B7).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Estimated Cost",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$total $currency",
                      style: const TextStyle(
                        color: Color(0xFF9EE7B7),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9EE7B7).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Color(0xFF9EE7B7),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          if (items.isNotEmpty)
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final item = items[i];
                final name = item["name"] ?? "";
                final variant = item["variantLabel"] ?? "";
                final qty = item["quantity"] ?? 0;
                final unit = item["unit"] ?? "";
                final price = item["total"] ?? 0;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (variant.toString().isNotEmpty)
                            Text(
                              "Type: $variant",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "$price JOD",
                          style: const TextStyle(
                            color: Color(0xFF9EE7B7),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          "$qty $unit",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _downloading ? null : _downloadEstimateFile,
                icon: _downloading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  _downloading
                      ? "Downloading..."
                      : "Download Details (PDF/JSON)",
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyEstimateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Row(
        children: [
          Icon(Icons.calculate_outlined, color: Colors.white.withOpacity(0.5)),
          const SizedBox(width: 12),
          const Text(
            "No estimation generated yet.",
            style: TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Project Info"),
          const SizedBox(height: 16),
          _infoRow(Icons.location_on_outlined, "Location", p["location"]),
          _infoRow(Icons.square_foot_rounded, "Area", "${p["area"]} m²"),
          _infoRow(Icons.layers_outlined, "Floors", p["floors"]),
          _infoRow(Icons.brush_outlined, "Finishing", p["finishingLevel"]),
          _infoRow(Icons.home_work_outlined, "Building", p["buildingType"]),
          if ((p["description"] ?? "").toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                p["description"],
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContractorCard(Map<String, dynamic> p) {
    final c = p["contractor"];
    if (c == null) return const SizedBox.shrink();

    final map = (c is Map) ? c : {};
    final name = map["name"] ?? "Unknown Contractor";
    final phone = map["phone"] ?? "";
    final email = map["email"] ?? "";

    final img = _toAbsoluteUrl(map["profileImageUrl"] ?? map["profileImage"] ?? "");

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2C24),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF9EE7B7).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF9EE7B7),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                "Assigned Contractor",
                style: TextStyle(
                  color: Color(0xFF9EE7B7),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white10,
                backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
                child: img.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOffersSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Received Offers",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _refreshOffers,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text("Refresh"),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF9EE7B7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<dynamic>>(
          future: _offersFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snap.hasError)
              return Text(
                "Error: ${snap.error}",
                style: const TextStyle(color: Colors.red),
              );

            final offers = snap.data ?? [];
            if (offers.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: _cardDeco(),
                child: const Column(
                  children: [
                    Icon(Icons.inbox_outlined, color: Colors.white38, size: 40),
                    SizedBox(height: 10),
                    Text(
                      "No offers received yet",
                      style: TextStyle(color: Colors.white38),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: offers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _buildOfferCard(offers[i]),
            );
          },
        ),
      ],
    );
  }

  // ✅✅ التعديل هنا: إضافة زر Reject ✅✅
  Widget _buildOfferCard(dynamic o) {
    final m = (o as Map);
    final id = m["_id"] ?? m["id"];
    final price = m["price"];
    final msg = m["message"] ?? "";
    final contractor = m["contractor"] is Map ? m["contractor"] : {};
    final name = contractor["name"] ?? "Unknown";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF9EE7B7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$price JOD",
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (msg.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              msg,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          
          // Action Buttons: Accept & Reject
          Row(
            children: [
              // زر القبول
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: (_processingOffer) ? null : () => _acceptOffer(id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9EE7B7),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _processingOffer
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            "Accept",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // زر الرفض
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: (_processingOffer) ? null : () => _rejectOffer(id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Reject",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _acceptOffer(String offerId) async {
    setState(() => _processingOffer = true);
    try {
      await _service.acceptOffer(projectId: widget.projectId, offerId: offerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Offer accepted! Project moved to In Progress."),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _processingOffer = false);
    }
  }

  // ✅✅ دالة الرفض الجديدة ✅✅
  Future<void> _rejectOffer(String offerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF15221D),
        title: const Text("Reject Offer?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Rejecting this offer will cancel the entire project. Are you sure?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Reject & Cancel", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _processingOffer = true);
    try {
      // ✅ يجب إضافة هذه الدالة في ProjectService
      await _service.rejectOfferAndCancel(projectId: widget.projectId, offerId: offerId);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Offer rejected and project cancelled."),
          backgroundColor: Colors.orange,
        ),
      );
      _load(); 
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _processingOffer = false);
    }
  }

  BoxDecoration _cardDeco() {
    return BoxDecoration(
      color: const Color(0xFF15221D),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.05)),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const Spacer(),
          Text(
            (value ?? "-").toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color ?? Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  color: color ?? Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg, fg;
    String text = status.replaceAll("_", " ");
    switch (status) {
      case "open":
        bg = Colors.green.withOpacity(0.2);
        fg = Colors.greenAccent;
        break;
      case "in_progress":
        bg = Colors.orange.withOpacity(0.2);
        fg = Colors.orangeAccent;
        break;
      case "completed":
        bg = Colors.blue.withOpacity(0.2);
        fg = Colors.blueAccent;
        break;
      case "cancelled": // ✅ حالة الإلغاء
        bg = Colors.red.withOpacity(0.2);
        fg = Colors.redAccent;
        break;
      default:
        bg = Colors.white10;
        fg = Colors.white54;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
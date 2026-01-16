import 'package:flutter/material.dart';
import '../services/project_service.dart';

class ProjectDetailsPage extends StatefulWidget {
  final String projectId;
  const ProjectDetailsPage({super.key, required this.projectId});

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  final _service = ProjectService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  Future<List<dynamic>>? _offersFuture;
  bool _accepting = false;

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

      // server might return { project: {...} } or project directly
      final project = (res["project"] is Map)
          ? Map<String, dynamic>.from(res["project"])
          : Map<String, dynamic>.from(res);

      setState(() => _data = project);

      // ✅ load offers (client)
      _offersFuture = _service.getProjectOffers(projectId: widget.projectId);
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

  // ====================== URL helpers (for images) ======================

  String _baseUrlFromService() {
    try {
      final dynamic s = _service;
      final v = s.baseUrl;
      if (v is String) return v;
    } catch (_) {}
    return "";
  }

  String _joinUrl(String base, String path) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path.substring(1) : path;
    return "$b/$p";
  }

  String _toAbsoluteUrl(String maybeUrlOrPath) {
    final v = maybeUrlOrPath.trim();
    if (v.isEmpty) return "";

    if (v.startsWith("http://") || v.startsWith("https://")) return v;

    if (v.startsWith("/")) {
      final base = _baseUrlFromService();
      if (base.isEmpty) return v;
      return _joinUrl(base, v);
    }

    return v;
  }

  // ====================== UI ======================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1814),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Project Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : RefreshIndicator(onRefresh: _load, child: _buildContent()),
    );
  }

  Widget _errorView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.error_outline, size: 46, color: Colors.white.withOpacity(0.7)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _load,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9EE7B7),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text("Retry"),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final p = _data ?? {};
    final title = (p["title"] ?? p["name"] ?? "Untitled").toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ===== Title Card =====
        _card(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ===== Estimate Card =====
        if (p["estimation"] != null || p["estimate"] != null) _buildEstimateCard(p),
        if (p["estimation"] == null && p["estimate"] == null)
          _card(
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.payments_outlined, color: Colors.white70),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "No estimation yet",
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // ===== Info Card =====
        _card(
          child: Column(
            children: [
              _row("Status", _statusChip(p["status"])),
              _rowText("Location", p["location"]),
              _rowText("Area", p["area"]),
              _rowText("Floors", p["floors"]),
              _rowText("Finishing", p["finishingLevel"]),
              _rowText("Building Type", p["buildingType"]),
              if ((p["description"] ?? "").toString().trim().isNotEmpty)
                _rowText("Description", p["description"]),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ===== Contractor Card (assigned contractor) =====
        _buildContractorCard(p),

        const SizedBox(height: 12),

        // ===== Offers (Client) =====
        _buildOffersSection(),

        const SizedBox(height: 12),

        // ===== Plan Analysis =====
        if (p["planAnalysis"] != null) _buildPlanAnalysisCard(p["planAnalysis"]),
      ],
    );
  }

  // ====================== Offers Section ======================

  Widget _buildOffersSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Offers",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: _refreshOffers,
                child: const Text("Refresh"),
              ),
            ],
          ),
          const SizedBox(height: 10),

          FutureBuilder<List<dynamic>>(
            future: _offersFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Text(
                  "Failed to load offers: ${snap.error}",
                  style: const TextStyle(color: Colors.redAccent),
                );
              }

              final offers = snap.data ?? [];
              if (offers.isEmpty) {
                return const Text(
                  "No offers yet.",
                  style: TextStyle(color: Colors.white70),
                );
              }

              return Column(
                children: offers.map((o) {
                  final m = (o as Map).cast<String, dynamic>();

                  final offerId = (m["_id"] ?? m["id"] ?? "").toString();
                  final price = (m["price"] ?? "-").toString();
                  final message = (m["message"] ?? "").toString().trim();

                  final contractor = m["contractor"];
                  final contractorName = contractor is Map
                      ? (contractor["name"] ?? "Contractor").toString()
                      : "Contractor";

                  final phone = contractor is Map ? (contractor["phone"] ?? "").toString() : "";
                  final email = contractor is Map ? (contractor["email"] ?? "").toString() : "";

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contractorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text("Price: $price", style: const TextStyle(color: Colors.white70)),
                        if (message.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text("Message: $message",
                              style: const TextStyle(color: Colors.white70)),
                        ],
                        if (phone.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text("Phone: $phone", style: const TextStyle(color: Colors.white60)),
                        ],
                        if (email.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text("Email: $email", style: const TextStyle(color: Colors.white60)),
                        ],
                        const SizedBox(height: 10),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_accepting || offerId.isEmpty)
                                ? null
                                : () => _acceptOffer(offerId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9EE7B7),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              minimumSize: const Size.fromHeight(46),
                            ),
                            child: _accepting
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text("Accept Offer"),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _acceptOffer(String offerId) async {
    setState(() => _accepting = true);
    try {
      await _service.acceptOffer(projectId: widget.projectId, offerId: offerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Offer accepted ✅")),
      );

      // Refresh project + offers after accept
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  // ====================== Contractor Card ======================

  Widget _buildContractorCard(Map<String, dynamic> p) {
    final raw = p["contractor"];

    if (raw == null) {
      return _card(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.engineering_outlined, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "No contractor assigned yet",
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    final c = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    final name = (c["name"] ?? c["fullName"] ?? c["companyName"] ?? "Contractor").toString();
    final email = (c["email"] ?? "").toString();
    final phone = (c["phone"] ?? "").toString();

    final imgRaw = (c["profileImageUrl"] ?? c["profileImage"] ?? "").toString();
    final img = _toAbsoluteUrl(imgRaw);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Assigned Contractor",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: img.isNotEmpty
                    ? Image.network(
                        img,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.person, color: Colors.white70),
                      )
                    : const Icon(Icons.person, color: Colors.white70),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    if (phone.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text("Phone: $phone", style: const TextStyle(color: Colors.white70)),
                    ],
                    if (email.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text("Email: $email", style: const TextStyle(color: Colors.white70)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ====================== Cards ======================

  Widget _buildEstimateCard(Map<String, dynamic> p) {
    final est = (p["estimation"] is Map)
        ? Map<String, dynamic>.from(p["estimation"])
        : (p["estimate"] is Map)
            ? Map<String, dynamic>.from(p["estimate"])
            : <String, dynamic>{};

    final total = est["totalCost"] ?? est["total"] ?? est["total_cost"];
    final currency = (est["currency"] ?? "JOD").toString();

    int itemsCount = 0;
    if (est["items"] is List) itemsCount = (est["items"] as List).length;

    String totalText;
    if (total == null) {
      totalText = "-";
    } else {
      final n = double.tryParse(total.toString());
      totalText = n == null ? total.toString() : n.toStringAsFixed(2);
    }

    return _card(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.payments_outlined, color: Colors.white70),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Estimated Cost",
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  "$totalText $currency",
                  style: const TextStyle(
                    color: Color(0xFF9EE7B7),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (itemsCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    "$itemsCount items",
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanAnalysisCard(dynamic planAnalysisRaw) {
    final pa = (planAnalysisRaw is Map)
        ? Map<String, dynamic>.from(planAnalysisRaw)
        : <String, dynamic>{};

    final totalArea = pa["totalArea"] ?? pa["area"] ?? pa["total_area"];
    final floors = pa["floors"];
    final rooms = pa["rooms"];
    final bathrooms = pa["bathrooms"] ?? pa["baths"];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Plan Analysis",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _bullet("Total Area", totalArea),
          _bullet("Floors", floors),
          _bullet("Rooms", rooms),
          _bullet("Bathrooms", bathrooms),
        ],
      ),
    );
  }

  // ====================== UI helpers ======================

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F261F).withOpacity(0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: child,
    );
  }

  Widget _row(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }

  Widget _rowText(String label, dynamic value) {
    return _row(
      label,
      Text((value ?? "-").toString(), style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _bullet(String label, dynamic value) {
    final v = (value == null) ? "-" : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text("• $label: $v", style: const TextStyle(color: Colors.white70)),
    );
  }

  Widget _statusChip(dynamic status) {
    final s = status?.toString().toLowerCase().trim() ?? "open";
    final isOpen = s == "open";
    final isProgress = s == "in_progress";

    final bg = isOpen
        ? Colors.green.withOpacity(0.18)
        : isProgress
            ? Colors.orange.withOpacity(0.18)
            : Colors.white.withOpacity(0.12);

    final fg = isOpen
        ? Colors.greenAccent
        : isProgress
            ? Colors.orangeAccent
            : Colors.white70;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: fg.withOpacity(0.25)),
        ),
        child: Text(
          s.replaceAll("_", " "),
          style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

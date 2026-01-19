import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/project_service.dart';
import '../services/session_service.dart';
import '../services/contract_service.dart';

class ContractorProjectDetailsPage extends StatefulWidget {
  final String projectId;

  const ContractorProjectDetailsPage({
    super.key,
    required this.projectId,
  });

  @override
  State<ContractorProjectDetailsPage> createState() =>
      _ContractorProjectDetailsPageState();
}

class _ContractorProjectDetailsPageState
    extends State<ContractorProjectDetailsPage> {
  final ProjectService _service = ProjectService();
  final ContractService _contractService = ContractService();

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _project;
  Map<String, dynamic>? _me;

  final _offerPriceCtrl = TextEditingController();
  final _offerMsgCtrl = TextEditingController();
  bool _submittingOffer = false;

  Map<String, dynamic>? _myOfferCache;

  // ✅ عقد المشروع الحالي (إذا موجود)
  Map<String, dynamic>? _myContract;
  bool _loadingContract = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _offerPriceCtrl.dispose();
    _offerMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _me = await SessionService.getUser();

      final res = await _service.getProjectById(widget.projectId);

      final p = (res is Map && res["project"] is Map)
          ? Map<String, dynamic>.from(res["project"])
          : Map<String, dynamic>.from(res as Map);

      // cache my offer + prefill form
      final myOffer = _myOffer(p);
      _myOfferCache = myOffer;
      if (myOffer != null) {
        _offerPriceCtrl.text = (myOffer["price"] ?? "").toString();
        _offerMsgCtrl.text = (myOffer["message"] ?? "").toString();
      } else {
        _offerPriceCtrl.clear();
        _offerMsgCtrl.clear();
      }

      setState(() => _project = p);

      // ✅ إذا المشروع صار بعد approve (مش open) نحاول نجيب العقد
      await _loadMyContractIfNeeded(p);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMyContractIfNeeded(Map<String, dynamic> p) async {
    final status = (p["status"] ?? "").toString().toLowerCase().trim();
    if (status == "open") {
      // لسا ما في approve
      setState(() => _myContract = null);
      return;
    }

    if (_loadingContract) return;

    setState(() => _loadingContract = true);
    try {
      final list = await _contractService.getMyContracts();

      Map<String, dynamic>? found;
      for (final c in list) {
        if (c is! Map) continue;
        final m = (c as Map).cast<String, dynamic>();

        final proj = m["project"];
        final projId =
            proj is Map ? (proj["_id"] ?? proj["id"]).toString() : proj?.toString();

        if (projId == widget.projectId) {
          found = m;
          break;
        }
      }

      if (mounted) setState(() => _myContract = found);
    } catch (_) {
      // لو فشلنا ما بنكسر الصفحة، بس ما بنعرض زر pdf
      if (mounted) setState(() => _myContract = null);
    } finally {
      if (mounted) setState(() => _loadingContract = false);
    }
  }

  // ---------------- Helpers ----------------

  String _fmtNum(dynamic v) {
    if (v == null) return "-";
    final n = double.tryParse(v.toString());
    if (n == null) return v.toString();
    return n.toStringAsFixed(2);
  }

  Map<String, dynamic> _estimationOf(Map<String, dynamic> p) {
    if (p["estimation"] is Map) return Map<String, dynamic>.from(p["estimation"]);
    if (p["estimate"] is Map) return Map<String, dynamic>.from(p["estimate"]);
    if (p["estimationResult"] is Map) {
      return Map<String, dynamic>.from(p["estimationResult"]);
    }
    return {};
  }

  String _myId() {
    final m = _me ?? {};
    return (m["id"] ?? m["_id"] ?? "").toString();
  }

  Map<String, dynamic>? _myOffer(Map<String, dynamic> p) {
    final myId = _myId();
    if (myId.isEmpty) return null;

    final offers = p["offers"];
    if (offers is! List) return null;

    for (final o in offers) {
      if (o is! Map) continue;
      final m = (o as Map).cast<String, dynamic>();
      final c = m["contractor"];
      final cid = c is Map ? (c["_id"] ?? c["id"]).toString() : c?.toString();
      if (cid == myId) return m;
    }
    return null;
  }

  Future<void> _submitOffer() async {
    final p = _project ?? {};
    final status = (p["status"] ?? "").toString().toLowerCase().trim();

    // ✅ بعد approve (مش open) ممنوع إرسال/تحديث
    if (status.isNotEmpty && status != "open") {
      _snack("This project is not open for offers.");
      return;
    }

    final priceStr = _offerPriceCtrl.text.trim();
    final price = double.tryParse(priceStr);
    if (price == null || price <= 0) {
      _snack("Enter a valid price.");
      return;
    }

    setState(() => _submittingOffer = true);
    try {
      // same endpoint (UPSERT on backend)
      await _service.createOffer(
        projectId: widget.projectId,
        price: price,
        message: _offerMsgCtrl.text.trim(),
      );

      final isUpdate = _myOfferCache != null;
      _snack(isUpdate ? "Offer updated ✅" : "Offer sent ✅");

      await _load();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _submittingOffer = false);
    }
  }

  Future<void> _openContractPdf() async {
    final c = _myContract;
    if (c == null) {
      _snack("Contract not found yet.");
      return;
    }

    // ✅ الأفضل: إذا العقد فيه contractFile (Cloudinary URL)
    final pdfUrl = (c["contractFile"] ?? c["pdfUrl"] ?? "").toString();

    if (pdfUrl.trim().isNotEmpty) {
      final uri = Uri.parse(pdfUrl);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _snack("Could not open PDF.");
      return;
    }

    // ✅ بديل: افتح endpoint بالـ id
    final contractId = (c["_id"] ?? c["id"] ?? "").toString();
    if (contractId.isEmpty) {
      _snack("Contract id missing.");
      return;
    }

    // هذا endpoint محمي (Bearer) — فتحه بالمتصفح ممكن يطلب auth
    // لذلك الأفضل أنك تخزن contractFile دائمًا.
    _snack("PDF url is missing. Please ensure contractFile is saved.");
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- UI ----------------

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
              : RefreshIndicator(onRefresh: _load, child: _content()),
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

  Widget _content() {
    final p = _project ?? {};
    final title = (p["title"] ?? p["name"] ?? "Project").toString();

    final est = _estimationOf(p);
    final total = est["totalCost"] ?? est["total"] ?? est["total_cost"];
    final currency = (est["currency"] ?? "JOD").toString();

    final status = (p["status"] ?? "").toString().toLowerCase().trim();
    final canOffer = status.isEmpty || status == "open";
    final isUpdate = _myOfferCache != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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

        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Client Estimate",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.payments_outlined, color: Color(0xFF9EE7B7)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      total == null ? "No estimate available." : "${_fmtNum(total)} $currency",
                      style: const TextStyle(
                        color: Color(0xFF9EE7B7),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildEstimationItems(est),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ✅ بعد approve: اعرض زر PDF (لو العقد موجود)
        if (!canOffer) _contractCard(),

        // ✅ قبل approve (open): اعرض offer card
        if (canOffer) _offerCard(isUpdate: isUpdate, status: status),
      ],
    );
  }

  Widget _contractCard() {
    final c = _myContract;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Contract",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),

          if (_loadingContract)
            const Text("Loading contract...", style: TextStyle(color: Colors.white70))
          else if (c == null)
            const Text(
              "No contract found yet for this project.",
              style: TextStyle(color: Colors.white70),
            )
          else ...[
            _rowText("Agreed Price", c["agreedPrice"]),
            _rowText("Status", c["status"]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openContractPdf,
                icon: const Icon(Icons.picture_as_pdf),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9EE7B7),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size.fromHeight(48),
                ),
                label: const Text("Open Contract PDF"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEstimationItems(Map<String, dynamic> est) {
    final items = est["items"];
    if (items is! List || items.isEmpty) {
      return const Text(
        "No estimate breakdown available.",
        style: TextStyle(color: Colors.white70),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        title: Text(
          "Estimate Breakdown (${items.length} items)",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        children: [
          ...items.map((it) {
            if (it is! Map) return const SizedBox.shrink();
            final m = it.cast<String, dynamic>();

            final name = (m["name"] ?? m["materialName"] ?? "Item").toString();
            final qty = m["qty"] ?? m["quantity"];
            final unit = (m["unit"] ?? "").toString();
            final unitPrice = m["unitPrice"] ?? m["pricePerUnit"];
            final total = m["total"] ?? m["totalCost"];

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
                  Text(name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 6),
                  Text(
                    "Qty: ${qty ?? "-"} ${unit.isEmpty ? "" : unit}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Unit Price: ${_fmtNum(unitPrice)}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Item Total: ${_fmtNum(total)}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ✅ خيار 2: Update Offer يظهر فقط إذا status == open
  Widget _offerCard({required bool isUpdate, required String status}) {
    final canEditOffer = status.isEmpty || status == "open";

    // ✅ إذا مش open (بعد approve) ما بدنا كرت offer أصلاً
    if (!canEditOffer) {
      return const SizedBox.shrink();
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUpdate ? "Update Offer" : "Send Offer",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _offerPriceCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Offer Price",
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _offerMsgCtrl,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Message (optional)",
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submittingOffer ? null : _submitOffer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9EE7B7),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                minimumSize: const Size.fromHeight(48),
              ),
              child: _submittingOffer
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isUpdate ? "Update Offer" : "Send Offer"),
            ),
          ),
        ],
      ),
    );
  }

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

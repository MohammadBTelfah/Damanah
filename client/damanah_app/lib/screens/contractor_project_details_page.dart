import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart'; // ✅ تأكد من إضافة intl في pubspec.yaml

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
  bool _creatingContract = false; // ✅ حالة تحميل إنشاء العقد

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

      await _loadMyContractIfNeeded(p);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMyContractIfNeeded(Map<String, dynamic> p) async {
    final status = (p["status"] ?? "").toString().toLowerCase().trim();
    
    // إذا المشروع لا يزال مفتوحاً، لا يوجد عقد بعد
    if (status == "open") {
      setState(() => _myContract = null);
      return;
    }

    if (_loadingContract) return;

    setState(() => _loadingContract = true);
    try {
      // نجلب كل عقود المقاول ونبحث عن العقد الخاص بهذا المشروع
      final list = await _contractService.getMyContracts();

      Map<String, dynamic>? found;
      for (final c in list) {
        if (c is! Map) continue;
        final m = (c as Map).cast<String, dynamic>();

        final proj = m["project"];
        final projId = proj is Map 
            ? (proj["_id"] ?? proj["id"]).toString() 
            : proj?.toString();

        if (projId == widget.projectId) {
          found = m;
          break;
        }
      }

      if (mounted) setState(() => _myContract = found);
    } catch (_) {
      // في حال الفشل، نفترض عدم وجود عقد حالياً
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
      _snack("No contract data available.");
      return;
    }

    final pdfUrl = (c["contractFile"] ?? c["pdfUrl"] ?? "").toString();

    if (pdfUrl.trim().isNotEmpty) {
      final uri = Uri.parse(pdfUrl);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _snack("Could not open PDF.");
      return;
    }
    _snack("PDF url is missing. Please create the contract first.");
  }

  // ✅ دالة جديدة: تفتح حوار لإنشاء العقد
  void _onTapCreateContract() {
    final p = _project ?? {};
    
    // استخراج بيانات العميل
    final ownerObj = p["owner"];
    final clientId = (ownerObj is Map ? (ownerObj["_id"] ?? ownerObj["id"]) : ownerObj).toString();
    final contractorId = _myId();

    // السعر: نأخذه من العرض المقبول أو من حقل الإدخال
    double? initialPrice;
    if (_myOfferCache != null) {
      initialPrice = double.tryParse(_myOfferCache!["price"].toString());
    }

    showDialog(
      context: context,
      builder: (_) => _CreateContractDialog(
        initialPrice: initialPrice,
        onSubmit: (data) async {
          // إغلاق الديالوج
          Navigator.pop(context);
          // استدعاء API الإنشاء
          await _createContractApiCall(
            clientId: clientId,
            contractorId: contractorId,
            data: data,
          );
        },
      ),
    );
  }

  // ✅ دالة جديدة: استدعاء الـ API لإنشاء العقد
  Future<void> _createContractApiCall({
    required String clientId,
    required String contractorId,
    required Map<String, dynamic> data,
  }) async {
    setState(() => _creatingContract = true);
    try {
      await _contractService.createContract(
        projectId: widget.projectId,
        clientId: clientId,
        contractorId: contractorId,
        agreedPrice: data['agreedPrice'],
        durationMonths: int.tryParse(data['duration'] ?? "1"),
        paymentTerms: data['paymentTerms'],
        startDate: data['startDate'],
        endDate: data['endDate'],
        terms: data['terms'],
      );

      _snack("Contract Created Successfully! ✅");
      
      // إعادة تحميل الصفحة لجلب العقد الجديد
      _load(); 
    } catch (e) {
      _snack("Failed to create contract: $e");
    } finally {
      if (mounted) setState(() => _creatingContract = false);
    }
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
    // يمكن تقديم عرض فقط إذا كانت الحالة open
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

        // ✅ عرض كرت العقد: إما لإنشاء العقد أو لعرضه
        if (!canOffer) _contractCard(),

        // ✅ عرض كرت العرض: لتقديم أو تحديث السعر
        if (canOffer) _offerCard(isUpdate: isUpdate, status: status),
      ],
    );
  }

  // ✅ كرت العقد المحدث: يعرض زر الإنشاء إذا لم يكن موجوداً
  Widget _contractCard() {
    final c = _myContract;
    final hasContract = c != null;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Contract",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              if (_loadingContract || _creatingContract)
                 const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 10),

          if (_loadingContract)
            const Text("Loading status...", style: TextStyle(color: Colors.white70))
          else if (hasContract) ...[
            // ✅ إذا العقد موجود، نعرض بياناته وزر الفتح
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
          ] else ...[
            // ✅ إذا العقد غير موجود، نعرض زر الإنشاء
            const Text(
              "Contract pending creation.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _creatingContract ? null : _onTapCreateContract,
                icon: const Icon(Icons.edit_document),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9EE7B7),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size.fromHeight(48),
                ),
                label: const Text("Create Contract"),
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

  Widget _offerCard({required bool isUpdate, required String status}) {
    final canEditOffer = status.isEmpty || status == "open";

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

// ✅ ويدجت داخلي (Private Widget) لنموذج إنشاء العقد
class _CreateContractDialog extends StatefulWidget {
  final double? initialPrice;
  final Function(Map<String, dynamic>) onSubmit;

  const _CreateContractDialog({
    this.initialPrice,
    required this.onSubmit,
  });

  @override
  State<_CreateContractDialog> createState() => _CreateContractDialogState();
}

class _CreateContractDialogState extends State<_CreateContractDialog> {
  final _priceCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _paymentTermsCtrl = TextEditingController();
  final _termsCtrl = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    if (widget.initialPrice != null) {
      _priceCtrl.text = widget.initialPrice.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    // استخدمنا Dialog عادي، يمكن استخدام AlertDialog
    return Dialog(
      backgroundColor: const Color(0xFF1A2C24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Create Contract",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            _field("Agreed Price (JOD)", _priceCtrl, isNumber: true),
            _field("Duration (Months)", _durationCtrl, isNumber: true),
            _field("Payment Terms", _paymentTermsCtrl),
            _field("Terms & Conditions", _termsCtrl, lines: 3),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _datePickerBtn("Start Date", _startDate, (d) => setState(() => _startDate = d))),
                const SizedBox(width: 10),
                Expanded(child: _datePickerBtn("End Date", _endDate, (d) => setState(() => _endDate = d))),
              ],
            ),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9EE7B7),
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                   final price = double.tryParse(_priceCtrl.text) ?? 0;
                   // يمكنك إضافة validation هنا
                   
                   final data = {
                     "agreedPrice": price,
                     "duration": _durationCtrl.text,
                     "paymentTerms": _paymentTermsCtrl.text,
                     "terms": _termsCtrl.text,
                     "startDate": _startDate?.toIso8601String(),
                     "endDate": _endDate?.toIso8601String(),
                   };
                   widget.onSubmit(data);
                },
                child: const Text("Create Now"),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {bool isNumber = false, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: lines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _datePickerBtn(String label, DateTime? date, Function(DateTime) onPick) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: date ?? now,
          firstDate: now.subtract(const Duration(days: 365)),
          lastDate: now.add(const Duration(days: 365 * 5)),
        );
        if (d != null) onPick(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          date == null ? label : DateFormat("yyyy-MM-dd").format(date),
          style: TextStyle(color: date == null ? Colors.white60 : Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
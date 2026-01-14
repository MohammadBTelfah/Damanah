import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/project_service.dart';

class CreateProjectFlow extends StatefulWidget {
  final ScrollController? scrollController;
  const CreateProjectFlow({super.key, this.scrollController});

  @override
  State<CreateProjectFlow> createState() => _CreateProjectFlowState();
}

class _CreateProjectFlowState extends State<CreateProjectFlow> {
  final _service = ProjectService();

  int _step = 0;
  bool _loading = false;

  File? _planFile;

  Map<String, dynamic>? _analysis;
  final _areaCtrl = TextEditingController();
  final _floorsCtrl = TextEditingController();
  final _roomsCtrl = TextEditingController();
  final _bathsCtrl = TextEditingController();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  String _finishing = "basic";

  // ✅ NEW: building type
  String _buildingType = "house"; // house/apartment/villa/commercial... حسب ما بدك

  List<dynamic> _materials = [];
  final Map<String, String> _selectedVariant = {}; // materialId -> variantKey

  Map<String, dynamic>? _estimate;
  String? _projectId;

  // ✅ NEW: contractors cache
  List<dynamic> _contractors = [];
  bool _contractorsLoading = false;

  @override
  void dispose() {
    _areaCtrl.dispose();
    _floorsCtrl.dispose();
    _roomsCtrl.dispose();
    _bathsCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {Color color = Colors.red}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  InputDecoration _dec(String hint, {Widget? suffix, EdgeInsets? padding}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      filled: true,
      fillColor: const Color(0xFF2F463D),
      suffixIcon: suffix,
      contentPadding:
          padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _pickPlan() async {
    if (_loading) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() {
      _planFile = File(result.files.single.path!);
    });
  }

  // ✅ fallback manual review (Step 2)
  void _goManualReview({String? msg}) {
    _analysis = {}; // فاضي

    if (_floorsCtrl.text.trim().isEmpty) _floorsCtrl.text = "1";

    setState(() => _step = 1);

    if (msg != null) {
      _snack(msg, color: Colors.orange);
    }
  }

  Future<void> _analyzePlan() async {
    if (_loading) return;

    // إذا ما في ملف، خليه يدخل manual
    if (_planFile == null) {
      _goManualReview(
        msg: "Auto analysis unavailable. Please fill details manually.",
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final data = await _service.analyzePlan(filePath: _planFile!.path);

      final analysis = (data["analysis"] is Map)
          ? Map<String, dynamic>.from(data["analysis"])
          : <String, dynamic>{};

      final area = (analysis["totalArea"] ?? analysis["area"] ?? "").toString();
      final floors = (analysis["floors"] ?? "").toString();
      final rooms = (analysis["rooms"] ?? "").toString();
      final baths = (analysis["bathrooms"] ?? "").toString();
      final loc = (analysis["locationGuess"] ?? "").toString();

      _areaCtrl.text = area;
      _floorsCtrl.text = floors.isEmpty ? "1" : floors;
      _roomsCtrl.text = rooms;
      _bathsCtrl.text = baths;
      if (loc.trim().isNotEmpty) _locationCtrl.text = loc;

      setState(() {
        _analysis = analysis;
        _step = 1;
      });
    } catch (e) {
      final msg = e.toString();

      final shouldManual =
          msg.contains("AI_UNAVAILABLE") || msg.contains("(503)") || msg.contains("(429)");

      if (shouldManual) {
        _goManualReview(
          msg: "Auto analysis failed. Please fill details manually.",
        );
      } else {
        _snack(msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goProjectInfo() async {
    if (_loading) return;

    final area = double.tryParse(_areaCtrl.text.trim());
    final floors = int.tryParse(_floorsCtrl.text.trim());

    if (area == null || area <= 0) {
      _snack("Area must be a valid number");
      return;
    }
    if (floors == null || floors <= 0) {
      _snack("Floors must be a valid integer");
      return;
    }

    _analysis ??= {};
    _analysis!["totalArea"] = area;
    _analysis!["floors"] = floors;

    final rooms = int.tryParse(_roomsCtrl.text.trim());
    final baths = int.tryParse(_bathsCtrl.text.trim());
    if (rooms != null) _analysis!["rooms"] = rooms;
    if (baths != null) _analysis!["bathrooms"] = baths;

    setState(() => _step = 2);
  }

  Future<void> _createProjectThenLoadMaterials() async {
    if (_loading) return;

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _snack("Title is required");
      return;
    }

    final area = double.tryParse(_areaCtrl.text.trim());
    final floors = int.tryParse(_floorsCtrl.text.trim());

    if (area == null || area <= 0) {
      _snack("Invalid area");
      return;
    }
    if (floors == null || floors <= 0) {
      _snack("Invalid floors");
      return;
    }

    setState(() => _loading = true);

    try {
      final id = await _service.createProjectAndReturnId(
        title: title,
        description: _descCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        area: area,
        floors: floors,
        finishingLevel: _finishing,
        buildingType: _buildingType, // ✅ NEW
        planAnalysis: _analysis,
      );

      final mats = await _service.getMaterials();

      setState(() {
        _projectId = id;
        _materials = mats;
        _step = 3;
      });
    } catch (e) {
      _snack("Create/load failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ مسموح Estimate بدون اختيار مواد
  Future<void> _runEstimate() async {
    if (_loading) return;

    if (_projectId == null || _projectId!.isEmpty) {
      _snack("No projectId (Project was not created)");
      return;
    }

    final selections = _selectedVariant.entries
        .map((e) => {"materialId": e.key, "variantKey": e.value})
        .toList();

    setState(() => _loading = true);

    try {
      final data = await _service.estimateProject(
        projectId: _projectId!,
        selections: selections,
      );

      setState(() {
        _estimate = data;
        _step = 4;
      });
    } catch (e) {
      _snack("Estimate failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =============================
  // ✅ NEW: Step 5 actions
  // =============================

  Future<void> _saveProject() async {
    if (_projectId == null) {
      _snack("No projectId");
      return;
    }
    setState(() => _loading = true);
    try {
      await _service.saveProject(projectId: _projectId!);
      _snack("Project saved ✅", color: Colors.green);
    } catch (e) {
      _snack("Save failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadEstimate() async {
    if (_projectId == null) {
      _snack("No projectId");
      return;
    }
    setState(() => _loading = true);
    try {
      final filePath = await _service.downloadEstimateToFile(projectId: _projectId!);
      _snack("Downloaded ✅\n$filePath", color: Colors.green);
    } catch (e) {
      _snack("Download failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ensureContractorsLoaded() async {
    if (_contractors.isNotEmpty || _contractorsLoading) return;

    setState(() => _contractorsLoading = true);
    try {
      final list = await _service.getContractors();
      setState(() => _contractors = list);
    } catch (e) {
      _snack("Load contractors failed: $e");
    } finally {
      if (mounted) setState(() => _contractorsLoading = false);
    }
  }

  Future<void> _openContractorPicker({required bool assign}) async {
    if (_projectId == null) {
      _snack("No projectId");
      return;
    }

    await _ensureContractorsLoaded();

    if (_contractors.isEmpty) {
      _snack("No contractors found");
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1814),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Text(
                  assign ? "Assign Contractor" : "Share with Contractor",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _contractors.length,
                    separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.06)),
                    itemBuilder: (_, i) {
                      final c = (_contractors[i] is Map)
                          ? Map<String, dynamic>.from(_contractors[i])
                          : <String, dynamic>{};

                      final id = c["_id"]?.toString() ?? "";
                      final name = c["name"]?.toString() ??
                          c["fullName"]?.toString() ??
                          c["companyName"]?.toString() ??
                          "Contractor";

                      return ListTile(
                        title: Text(name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(id, style: const TextStyle(color: Colors.white38), maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () async {
                          Navigator.pop(context);

                          setState(() => _loading = true);
                          try {
                            if (assign) {
                              await _service.assignContractor(projectId: _projectId!, contractorId: id);
                              _snack("Assigned ✅", color: Colors.green);
                            } else {
                              await _service.shareProject(projectId: _projectId!, contractorId: id);
                              _snack("Shared ✅", color: Colors.green);
                            }
                          } catch (e) {
                            _snack("${assign ? "Assign" : "Share"} failed: $e");
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetShell({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0E1814),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: child,
    );
  }

  // =============================
  // UI
  // =============================

  @override
  Widget build(BuildContext context) {
    final sc = widget.scrollController;

    return _sheetShell(
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  const Expanded(
                    child: Text(
                      "New Project",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: List.generate(5, (i) {
                  final active = i <= _step;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i == 4 ? 0 : 8),
                      height: 6,
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFF9EE7B7) : Colors.white10,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                children: [
                  if (_step == 0) _buildStepUpload(),
                  if (_step == 1) _buildStepReview(),
                  if (_step == 2) _buildStepProjectInfo(),
                  if (_step == 3) _buildStepMaterials(),
                  if (_step == 4) _buildStepEstimate(), // ✅ updated
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9EE7B7),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildSecondaryButton(String text, VoidCallback onPressed, {IconData? icon}) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : onPressed,
        icon: Icon(icon ?? Icons.circle_outlined, color: Colors.white70, size: 18),
        label: Text(text, style: const TextStyle(color: Colors.white)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildStepUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Step 1: Upload your floor plan",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Optional: If auto-analysis fails, you can enter details manually.",
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F261F).withOpacity(0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _planFile == null
                    ? "No file selected"
                    : _planFile!.path.split(Platform.pathSeparator).last,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : _pickPlan,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text("Choose File"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _buildPrimaryButton("Analyze", _analyzePlan)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Step 2: Review & edit data",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "If auto-analysis is unavailable, fill these fields manually.",
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _areaCtrl,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: _dec("Area (m²) *"),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _floorsCtrl,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: _dec("Floors *"),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _roomsCtrl,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.text,
          decoration: _dec("Rooms (optional)"),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _bathsCtrl,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: _dec("Bathrooms (optional)"),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : () => setState(() => _step = 0),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text("Back"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _buildPrimaryButton("Next", _goProjectInfo)),
          ],
        ),
      ],
    );
  }

  // ✅ Step 3 updated: add Building Type dropdown
  Widget _buildStepProjectInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Step 3: Project details",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _titleCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: _dec("Project Title *"),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descCtrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 2,
          decoration: _dec(
            "Description (optional)",
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _locationCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: _dec("Location"),
        ),
        const SizedBox(height: 12),

        // ✅ NEW: Building Type
        DropdownButtonFormField<String>(
          value: _buildingType,
          decoration: _dec("Building Type"),
          dropdownColor: const Color(0xFF2F463D),
          iconEnabledColor: Colors.white,
          style: const TextStyle(color: Colors.white),
          items: const [
            DropdownMenuItem(value: "house", child: Text("House")),
            DropdownMenuItem(value: "villa", child: Text("Villa")),
            DropdownMenuItem(value: "apartment", child: Text("Apartment")),
            DropdownMenuItem(value: "commercial", child: Text("Commercial")),
          ],
          onChanged: (v) => setState(() => _buildingType = v ?? "house"),
        ),

        const SizedBox(height: 12),
        TextFormField(
          controller: _areaCtrl,
          readOnly: true,
          style: const TextStyle(color: Colors.white),
          decoration: _dec("Area (m²)"),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _floorsCtrl,
          readOnly: true,
          style: const TextStyle(color: Colors.white),
          decoration: _dec("Floors"),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _finishing,
          decoration: _dec("Finishing Level"),
          dropdownColor: const Color(0xFF2F463D),
          iconEnabledColor: Colors.white,
          style: const TextStyle(color: Colors.white),
          items: const [
            DropdownMenuItem(value: "basic", child: Text("Basic")),
            DropdownMenuItem(value: "medium", child: Text("Medium")),
            DropdownMenuItem(value: "premium", child: Text("Premium")),
          ],
          onChanged: (v) => setState(() => _finishing = v ?? "basic"),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : () => setState(() => _step = 1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text("Back"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildPrimaryButton(
                "Next",
                _createProjectThenLoadMaterials,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepMaterials() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Step 4: Choose materials",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Optional: you can skip any material and estimate will still work.",
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (_materials.isEmpty) ...[
          const Text(
            "No materials found",
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 12),
          _buildPrimaryButton("Estimate (Skip)", _runEstimate),
        ] else
          ..._materials.map((m) {
            final mat = (m is Map) ? Map<String, dynamic>.from(m) : <String, dynamic>{};
            final id = mat["_id"]?.toString() ?? "";
            final name = mat["name"]?.toString() ?? "Material";
            final variants = (mat["variants"] is List) ? List.from(mat["variants"]) : <dynamic>[];

            final fallbackVariants = [
              {"key": "basic", "label": "Basic"},
              {"key": "medium", "label": "Medium"},
              {"key": "premium", "label": "Premium"},
            ];

            final list = variants.isNotEmpty ? variants : fallbackVariants;
            final String? current = _selectedVariant[id];

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F261F).withOpacity(0.6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: current,
                      isExpanded: true,
                      decoration: _dec(
                        "Type",
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      dropdownColor: const Color(0xFF2F463D),
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white),
                      items: list.map((v) {
                        final vm = (v is Map) ? Map<String, dynamic>.from(v) : <String, dynamic>{};
                        return DropdownMenuItem<String>(
                          value: vm["key"]?.toString(),
                          child: Text(
                            vm["label"]?.toString() ?? vm["key"]?.toString() ?? "",
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (id.isEmpty || v == null) return;
                        setState(() => _selectedVariant[id] = v);
                      },
                    ),
                  ),
                  if (current != null) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: "Clear",
                      onPressed: _loading ? null : () => setState(() => _selectedVariant.remove(id)),
                      icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        if (_materials.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : () => setState(() => _step = 2),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text("Back"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _buildPrimaryButton("Estimate", _runEstimate)),
            ],
          ),
        ],
      ],
    );
  }

  // ✅ Step 5 updated: buttons for Download/Save/Share/Assign + Finish
  Widget _buildStepEstimate() {
    final items = (_estimate?["items"] is List) ? List.from(_estimate?["items"]) : <dynamic>[];
    final total = _estimate?["totalCost"] ?? _estimate?["total"] ?? "";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Step 5: Estimate result",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),

        if (_estimate == null)
          const Text("No estimate yet", style: TextStyle(color: Colors.white60))
        else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F261F).withOpacity(0.6),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Total: $total JOD",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                ...items.take(8).map((it) {
                  final m = (it is Map) ? Map<String, dynamic>.from(it) : <String, dynamic>{};
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      "- ${m["name"] ?? "item"}  |  ${m["quantity"] ?? ""} ${m["unit"] ?? ""}  |  ${m["total"] ?? ""} JOD",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                }).toList(),
                if (items.length > 8)
                  const Text("...more items", style: TextStyle(color: Colors.white38)),
              ],
            ),
          ),

          const SizedBox(height: 14),

          _buildSecondaryButton("Download details", _downloadEstimate, icon: Icons.download),

          const SizedBox(height: 10),

          _buildSecondaryButton("Save project", _saveProject, icon: Icons.bookmark_add_outlined),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildSecondaryButton(
                  "Share",
                  () => _openContractorPicker(assign: false),
                  icon: Icons.share_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSecondaryButton(
                  "Assign",
                  () => _openContractorPicker(assign: true),
                  icon: Icons.handshake_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _buildPrimaryButton("Finish", () => Navigator.pop(context, true)),
        ],
      ],
    );
  }
}

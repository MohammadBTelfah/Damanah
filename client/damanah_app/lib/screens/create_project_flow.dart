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

  // Step 1 file
  File? _planFile;

  // Step 2 analysis editable
  Map<String, dynamic>? _analysis;
  final _areaCtrl = TextEditingController();
  final _floorsCtrl = TextEditingController();
  final _roomsCtrl = TextEditingController();
  final _bathsCtrl = TextEditingController();

  // Step 3 project info
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  String _finishing = "basic";

  // Step 4 materials
  List<dynamic> _materials = [];
  final Map<String, String> _selectedVariant = {}; // materialId -> variantKey

  // Step 5
  Map<String, dynamic>? _estimate;
  String? _projectId;

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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() {
      _planFile = File(result.files.single.path!);
    });
  }

  Future<void> _analyzePlan() async {
    if (_planFile == null) {
      _snack("Please upload a plan first");
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
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goProjectInfo() async {
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
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _snack("Title is required");
      return;
    }

    final area = double.tryParse(_areaCtrl.text.trim());
    final floors = int.tryParse(_floorsCtrl.text.trim());

    if (area == null || area <= 0) return _snack("Invalid area");
    if (floors == null || floors <= 0) return _snack("Invalid floors");

    setState(() => _loading = true);
    try {
      final id = await _service.createProjectAndReturnId(
        title: title,
        description: _descCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        area: area,
        floors: floors,
        finishingLevel: _finishing,
        planAnalysis: _analysis,
      );

      final mats = await _service.getMaterials();

      setState(() {
        _projectId = id;
        _materials = mats;
        _step = 3;
      });
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ تعديل: صار مسموح تعمل Estimate بدون ما تختار أي مادة
  Future<void> _runEstimate() async {
    if (_projectId == null) {
      _snack("No projectId");
      return;
    }

    final selections = _selectedVariant.entries
        .map((e) => {"materialId": e.key, "variantKey": e.value})
        .toList();

    setState(() => _loading = true);
    try {
      final data = await _service.estimateProject(
        projectId: _projectId!,
        selections: selections, // ممكن تكون []
      );

      setState(() {
        _estimate = data;
        _step = 4;
      });
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                        color: active
                            ? const Color(0xFF9EE7B7)
                            : Colors.white10,
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
                  if (_step == 3) _buildStepMaterials(), // ✅ معدل
                  if (_step == 4) _buildStepEstimate(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Steps UI ----------------

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
          "Step 2: Review & edit extracted data",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: _areaCtrl,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: _dec("Area (m²)"),
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: _floorsCtrl,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: _dec("Floors"),
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
          decoration: _dec("Project Title"),
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

        TextFormField(
          controller: _areaCtrl,
          readOnly: false,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: _dec("Area (m²)"),
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: _floorsCtrl,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
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
              child: _buildPrimaryButton("Next", _createProjectThenLoadMaterials),
            ),
          ],
        ),
      ],
    );
  }

  // ✅ تعديل Step 4: حل overflow + اختيار اختياري + زر clear
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

        if (_materials.isEmpty)
          const Text(
            "No materials found",
            style: TextStyle(color: Colors.white60),
          )
        else
          ..._materials.map((m) {
            final mat = (m is Map)
                ? Map<String, dynamic>.from(m)
                : <String, dynamic>{};

            final id = mat["_id"]?.toString() ?? "";
            final name = mat["name"]?.toString() ?? "Material";

            final variants = (mat["variants"] is List)
                ? List.from(mat["variants"])
                : <dynamic>[];

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
                  // ✅ name
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

                  // ✅ dropdown مرن (حل overflow)
                  Flexible(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: current,
                      isExpanded: true,
                      decoration: _dec(
                        "Type",
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      dropdownColor: const Color(0xFF2F463D),
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white),
                      items: list.map((v) {
                        final vm = (v is Map)
                            ? Map<String, dynamic>.from(v)
                            : <String, dynamic>{};
                        return DropdownMenuItem<String>(
                          value: vm["key"]?.toString(),
                          child: Text(
                            vm["label"]?.toString() ??
                                vm["key"]?.toString() ??
                                "",
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (id.isEmpty) return;
                        if (v == null) return;
                        setState(() => _selectedVariant[id] = v);
                      },
                    ),
                  ),

                  // ✅ clear selection
                  if (current != null) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: "Clear",
                      onPressed: _loading
                          ? null
                          : () {
                              setState(() => _selectedVariant.remove(id));
                            },
                      icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),

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
    );
  }

  Widget _buildStepEstimate() {
    final items = (_estimate?["items"] is List)
        ? List.from(_estimate?["items"])
        : <dynamic>[];
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
                  final m = (it is Map)
                      ? Map<String, dynamic>.from(it)
                      : <String, dynamic>{};
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      "- ${m["name"] ?? "item"}  |  ${m["quantity"] ?? ""} ${m["unit"] ?? ""}  |  ${m["total"] ?? ""} JOD",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                }).toList(),
                if (items.length > 8)
                  const Text(
                    "...more items",
                    style: TextStyle(color: Colors.white38),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildPrimaryButton("Finish", () => Navigator.pop(context, true)),
        ],
      ],
    );
  }
}

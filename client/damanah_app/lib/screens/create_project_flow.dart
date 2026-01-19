import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/project_service.dart';
import 'estimate_loading_page.dart';

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

  String _buildingType = "House";

  List<dynamic> _materials = [];
  
  // ✅ المتغيرات الجديدة للتحكم بالـ Checkbox والاختيارات
  final Set<String> _checkedMaterials = {}; 
  final Map<String, String> _selectedVariant = {};

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

  // --- Helpers ---
  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  Map<String, dynamic>? _sanitizePlanAnalysis(Map<String, dynamic>? analysis) {
    if (analysis == null) return null;
    final a = Map<String, dynamic>.from(analysis);
    if (a.containsKey("totalArea")) {
      final d = _toDouble(a["totalArea"]);
      if (d != null) a["totalArea"] = d;
    }
    if (a.containsKey("floors")) {
      final n = _toInt(a["floors"]);
      if (n != null) a["floors"] = n;
    }
    final roomsVal = a["rooms"];
    if (roomsVal is List) {
      a["roomsDetails"] = roomsVal;
      a["rooms"] = roomsVal.length;
    } else if (roomsVal is Map) {
      a["roomsDetails"] = [roomsVal];
      a["rooms"] = 1;
    } else {
      final n = _toInt(roomsVal);
      if (n != null) a["rooms"] = n;
    }
    final bathsVal = a["bathrooms"];
    if (bathsVal is List) {
      a["bathroomsDetails"] = bathsVal;
      a["bathrooms"] = bathsVal.length;
    } else if (bathsVal is Map) {
      a["bathroomsDetails"] = [bathsVal];
      a["bathrooms"] = 1;
    } else {
      final n = _toInt(bathsVal);
      if (n != null) a["bathrooms"] = n;
    }
    return a;
  }

  // --- Logic Steps ---

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

  void _goManualReview({String? msg}) {
    _analysis = {};
    if (_floorsCtrl.text.trim().isEmpty) _floorsCtrl.text = "1";
    setState(() => _step = 1);
    if (msg != null) _snack(msg, color: Colors.orange);
  }

  Future<void> _analyzePlan() async {
    if (_loading) return;

    if (_planFile == null) {
      _goManualReview(msg: "Auto analysis unavailable. Please fill details manually.");
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
      final roomsVal = analysis["rooms"];
      final bathsVal = analysis["bathrooms"];

      String roomsText = "";
      if (roomsVal is List) {
        roomsText = roomsVal.length.toString();
      } else {
        roomsText = (roomsVal ?? "").toString();
      }

      String bathsText = "";
      if (bathsVal is List) {
        bathsText = bathsVal.length.toString();
      } else {
        bathsText = (bathsVal ?? "").toString();
      }

      final loc = (analysis["locationGuess"] ?? "").toString();

      _areaCtrl.text = area;
      _floorsCtrl.text = floors.isEmpty ? "1" : floors;
      _roomsCtrl.text = roomsText;
      _bathsCtrl.text = bathsText;
      if (loc.trim().isNotEmpty) _locationCtrl.text = loc;

      setState(() {
        _analysis = analysis;
        _step = 1;
      });
    } catch (e) {
      final msg = e.toString();
      final shouldManual = msg.contains("AI_UNAVAILABLE") ||
          msg.contains("(503)") ||
          msg.contains("(429)");

      if (shouldManual) {
        _goManualReview(msg: "Auto analysis failed. Please fill details manually.");
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
    if (area == null || area <= 0) return _snack("Invalid area");
    if (floors == null || floors <= 0) return _snack("Invalid floors");

    final sanitizedAnalysis = _sanitizePlanAnalysis(_analysis);

    setState(() => _loading = true);

    try {
      final id = await _service.createProjectAndReturnId(
        title: title,
        description: _descCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        area: area,
        floors: floors,
        finishingLevel: _finishing,
        buildingType: _buildingType,
        planAnalysis: sanitizedAnalysis,
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

  // ✅ Step 4 Logic: التحقق من الاختيارات
  Future<void> _runEstimate() async {
    if (_loading) return;
    if (_projectId == null || _projectId!.isEmpty) {
      _snack("No projectId");
      return;
    }

    // 1. هل اختار المستخدم مادة واحدة على الأقل؟
    if (_checkedMaterials.isEmpty) {
      _snack("Please choose at least one material", color: Colors.orange);
      return;
    }

    final List<Map<String, String>> selections = [];

    // 2. هل اختار النوع لكل مادة تم تحديدها بالـ Checkbox؟
    for (String id in _checkedMaterials) {
      final variantKey = _selectedVariant[id];
      if (variantKey == null) {
        final m = _materials.firstWhere((e) => e["_id"] == id, orElse: () => {});
        final name = m["name"] ?? "Selected Material";
        _snack("Please select a type for '$name'", color: Colors.orange);
        return;
      }
      selections.add({"materialId": id, "variantKey": variantKey});
    }

    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EstimateLoadingPage(
          task: () async {
            final data = await _service.estimateProject(
              projectId: _projectId!,
              selections: selections,
            );
            _estimate = data;
            _step = 4;
          },
        ),
      ),
    );

    if (ok == true) {
      if (mounted) setState(() {});
    } else {
      _snack("Estimate failed");
    }
  }

  Future<void> _downloadEstimate() async {
    if (_projectId == null) return _snack("No projectId");
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

  Future<void> _publishProject() async {
    if (_projectId == null) return _snack("No projectId");
    setState(() => _loading = true);
    try {
      await _service.publishProject(projectId: _projectId!);
      if (!mounted) return;
      _snack("Published to all contractors ✅", color: Colors.green);
      Navigator.pop(context, true);
    } catch (e) {
      _snack("Publish failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =============================
  // ✅ منطق Assign To Specific Contractor
  // =============================

  void _showContractorPicker() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final contractors = await _service.getContractors(); 

      if (!mounted) return;
      setState(() => _loading = false);

      if (contractors.isEmpty) {
        _snack("No active contractors found.", color: Colors.orange);
        return;
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF0E1814),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (ctx) {
          return Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Select a Contractor",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: contractors.length,
                    separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.1)),
                    itemBuilder: (ctx, index) {
                      final c = contractors[index];
                      final name = c["name"] ?? "Unknown"; 
                      final id = c["_id"];

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF2F463D),
                          child: Text(name.toString().substring(0,1).toUpperCase(), style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(name, style: const TextStyle(color: Colors.white)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54),
                        onTap: () {
                          Navigator.pop(ctx);
                          _confirmAssign(id, name);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      _snack("Failed to load contractors: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _confirmAssign(String contractorId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1814),
        title: const Text("Confirm Assignment", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to assign project to '$name'?\nOther contractors won't see this project.", 
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _assignContractorApi(contractorId);
            },
            child: const Text("Assign", style: TextStyle(color: Color(0xFF9EE7B7))),
          ),
        ],
      ),
    );
  }

  Future<void> _assignContractorApi(String contractorId) async {
    if (_projectId == null) return;
    setState(() => _loading = true);
    try {
      await _service.assignContractor(projectId: _projectId!, contractorId: contractorId);
      
      if (!mounted) return;
      _snack("Project assigned successfully! ✅", color: Colors.green);
      Navigator.pop(context, true); 
    } catch (e) {
      _snack("Assign failed: $e");
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
                  if (_step == 4) _buildStepEstimate(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets ---

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
            : Text(text,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildStepUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Step 1: Upload your floor plan",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text("Optional: If auto-analysis fails, you can enter details manually.",
            style: TextStyle(color: Colors.white60, fontSize: 12)),
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
                _planFile == null ? "No file selected" : _planFile!.path.split(Platform.pathSeparator).last,
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        const Text("Step 2: Review & edit data",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextFormField(controller: _areaCtrl, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number, decoration: _dec("Area (m²) *")),
        const SizedBox(height: 12),
        TextFormField(controller: _floorsCtrl, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number, decoration: _dec("Floors *")),
        const SizedBox(height: 12),
        TextFormField(controller: _roomsCtrl, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number, decoration: _dec("Rooms (optional)")),
        const SizedBox(height: 12),
        TextFormField(controller: _bathsCtrl, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number, decoration: _dec("Bathrooms (optional)")),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : () => setState(() => _step = 0),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        const Text("Step 3: Project details",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextFormField(controller: _titleCtrl, style: const TextStyle(color: Colors.white), decoration: _dec("Project Title *")),
        const SizedBox(height: 12),
        TextFormField(controller: _descCtrl, style: const TextStyle(color: Colors.white), maxLines: 2, decoration: _dec("Description (optional)", padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10))),
        const SizedBox(height: 12),
        TextFormField(controller: _locationCtrl, style: const TextStyle(color: Colors.white), decoration: _dec("Location")),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _buildingType,
          decoration: _dec("Building Type"),
          dropdownColor: const Color(0xFF2F463D),
          iconEnabledColor: Colors.white,
          style: const TextStyle(color: Colors.white),
          items: const [
            DropdownMenuItem(value: "House", child: Text("House")),
            DropdownMenuItem(value: "villa", child: Text("Villa")),
            DropdownMenuItem(value: "commercial", child: Text("Commercial")),
          ],
          onChanged: (v) => setState(() => _buildingType = v ?? "House"),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _finishing,
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Back"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _buildPrimaryButton("Next", _createProjectThenLoadMaterials)),
          ],
        ),
      ],
    );
  }

  // =============================
  // ✅ Step 4: اختيار المواد مع Checkbox
  // =============================
  Widget _buildStepMaterials() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Step 4: Choose materials",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text("Check the box to include the material in your estimate.",
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 12),
        if (_materials.isEmpty) ...[
          const Text("No materials found", style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 12),
          _buildSecondaryButton("Retry Load", _createProjectThenLoadMaterials, icon: Icons.refresh),
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
            
            final isChecked = _checkedMaterials.contains(id);
            final String? current = _selectedVariant[id];

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F261F).withOpacity(0.6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isChecked 
                    ? const Color(0xFF9EE7B7).withOpacity(0.5) 
                    : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: isChecked,
                    activeColor: const Color(0xFF9EE7B7),
                    checkColor: Colors.black,
                    side: const BorderSide(color: Colors.white54, width: 2),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _checkedMaterials.add(id);
                        } else {
                          _checkedMaterials.remove(id);
                          _selectedVariant.remove(id); 
                        }
                      });
                    },
                  ),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(
                           name, 
                           style: TextStyle(
                             color: isChecked ? Colors.white : Colors.white54, 
                             fontWeight: FontWeight.w700,
                             fontSize: 15,
                           ),
                           maxLines: 1, overflow: TextOverflow.ellipsis
                         ),
                         const SizedBox(height: 8),
                         
                         SizedBox(
                           height: 44,
                           child: DropdownButtonFormField<String>(
                            value: current,
                            isExpanded: true,
                            hint: Text(
                              isChecked ? "Select Type" : "Not Selected",
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                            ),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              fillColor: isChecked ? const Color(0xFF2F463D) : Colors.black12,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            dropdownColor: const Color(0xFF2F463D),
                            iconEnabledColor: isChecked ? Colors.white : Colors.white24,
                            style: const TextStyle(color: Colors.white),
                            items: !isChecked ? [] : list.map((v) {
                              final vm = (v is Map) ? Map<String, dynamic>.from(v) : <String, dynamic>{};
                              return DropdownMenuItem<String>(
                                value: vm["key"]?.toString(),
                                child: Text(vm["label"]?.toString() ?? vm["key"]?.toString() ?? "", overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: !isChecked ? null : (v) {
                              if (id.isEmpty || v == null) return;
                              setState(() => _selectedVariant[id] = v);
                            },
                          ),
                         ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        if (_materials.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : () => setState(() => _step = 2),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Back"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _buildPrimaryButton("Calculate Selected", _runEstimate)),
            ],
          ),
        ],
      ],
    );
  }

  // =============================
  // ✅ Step 5: النتيجة + أزرار الـ Action
  // =============================
  Widget _buildStepEstimate() {
    final items = (_estimate?["items"] is List)
        ? List.from(_estimate?["items"])
        : <dynamic>[];
    final total = _estimate?["totalCost"] ?? _estimate?["total"] ?? "0";

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
          // --- Total Box ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2F463D), Color(0xFF0F261F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF9EE7B7).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Text("Estimated Total Cost", style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text(
                  "$total JOD",
                  style: const TextStyle(
                    color: Color(0xFF9EE7B7),
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          const Text("Breakdown:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // --- Items List ---
          ...items.map((it) {
            final m = (it is Map) ? Map<String, dynamic>.from(it) : <String, dynamic>{};
            final name = m["name"] ?? "Item";
            final variantLabel = m["variantLabel"] ?? ""; // From backend
            final qty = m["quantity"] ?? "0";
            final unit = m["unit"] ?? "";
            final price = m["total"] ?? "0";

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F261F).withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        "$price JOD",
                        style: const TextStyle(
                          color: Color(0xFF9EE7B7),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  if (variantLabel.toString().isNotEmpty)
                    Text(
                      "Type: $variantLabel",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9), 
                        fontSize: 13,
                        fontStyle: FontStyle.italic
                      ),
                    ),
                  
                  const SizedBox(height: 6),
                  Divider(color: Colors.white.withOpacity(0.05), height: 16),
                  
                  Row(
                    children: [
                       Icon(Icons.layers_outlined, color: Colors.white.withOpacity(0.5), size: 16),
                       const SizedBox(width: 6),
                       Text(
                         "$qty $unit",
                         style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                       ),
                    ],
                  )
                ],
              ),
            );
          }),
          
          const SizedBox(height: 24),

          _buildSecondaryButton("Download Details (PDF/JSON)", _downloadEstimate,
              icon: Icons.download),

          const SizedBox(height: 20),

          // ✅ صف الأزرار: Assign + Publish
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 58, // 1. قمنا بزيادة الارتفاع ليتسع للمحتوى
                  child: OutlinedButton(
                    onPressed: _loading ? null : _showContractorPicker,
                    style: OutlinedButton.styleFrom(
                      // 2. تقليل الحشوة الداخلية لتوفير مساحة
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      side: const BorderSide(color: Color(0xFF9EE7B7)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.person_add_alt_1, color: Color(0xFF9EE7B7), size: 22), // حجم الأيقونة مناسب
                        SizedBox(height: 2), // تقليل المسافة بين الأيقونة والنص
                        Text(
                          "Assign Specific", 
                          style: TextStyle(
                            color: Color(0xFF9EE7B7), 
                            fontSize: 11, // تصغير الخط قليلاً ليناسب المساحة
                            fontWeight: FontWeight.bold
                          )
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 58, // يجب توحيد الارتفاع مع الزر المجاور
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _publishProject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9EE7B7),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.public, size: 22),
                    label: const Text("Publish to All",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              "Publish to get offers from everyone, or Assign to start immediately.",
              style: TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}
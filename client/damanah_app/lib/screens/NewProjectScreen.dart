import 'package:flutter/material.dart';
import '../services/project_service.dart';

class NewProjectScreen extends StatefulWidget {
  final ScrollController? scrollController;

  const NewProjectScreen({
    super.key,
    this.scrollController,
  });

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _area = TextEditingController();
  final _floors = TextEditingController();

  String? _finishingLevel; // basic / standard / luxury
  bool _loading = false;

  String? _error; // ✅ لعرض الخطأ داخل الشاشة بدل SnackBar

  final _service = ProjectService();

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _area.dispose();
    _floors.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // سكّر الكيبورد
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final area = double.tryParse(_area.text.trim());
    final floors = int.tryParse(_floors.text.trim());

    if (_finishingLevel == null) {
      setState(() => _error = "Please select finishing level");
      return;
    }

    if (area == null || area <= 0) {
      setState(() => _error = "Area must be a valid number");
      return;
    }

    if (floors == null || floors <= 0) {
      setState(() => _error = "Floors must be a valid integer");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final projectId = await _service.createProjectAndReturnId(
        title: _title.text.trim(),
        description: _description.text.trim(),
        location: _location.text.trim(),
        area: area,
        floors: floors,
        finishingLevel: _finishingLevel!,
      );

      if (!mounted) return;

      // ✅ رجّع الـ projectId للـ BottomSheet (ClientHomeScreen رح يفتح UploadPlanScreen)
      Navigator.pop(context, projectId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      debugPrint("CREATE PROJECT ERROR: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _dec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      filled: true,
      fillColor: const Color(0xFF2F463D),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0E1814);
    const green = Color(0xFF9EE7B7);

    return Material(
      color: bg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),

            // ✅ Handle
            Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
            ),

            const SizedBox(height: 10),

            // ✅ Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      "New Project",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 6),

            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: widget.scrollController, // ✅ مهم للـ BottomSheet
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  children: [
                    TextFormField(
                      controller: _title,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec("Project Title"),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? "Title is required" : null,
                    ),
                    const SizedBox(height: 12),

                    // ✅ Description أصغر
                    TextFormField(
                      controller: _description,
                      style: const TextStyle(color: Colors.white),
                      minLines: 2,
                      maxLines: 2,
                      decoration: _dec("Description"),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? "Description is required"
                          : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _location,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec("Location"),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? "Location is required"
                          : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _area,
                      style: const TextStyle(color: Colors.white),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: _dec("Area (m²)"),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? "Area is required" : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _floors,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: _dec("Floors"),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? "Floors is required"
                          : null,
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: _finishingLevel,
                      decoration: _dec("Finishing Level"),
                      dropdownColor: const Color(0xFF2F463D),
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: "basic", child: Text("Basic")),
                        DropdownMenuItem(value: "standard", child: Text("Standard")),
                        DropdownMenuItem(value: "luxury", child: Text("Luxury")),
                      ],
                      onChanged: _loading ? null : (v) => setState(() => _finishingLevel = v),
                      validator: (v) => v == null ? "Select finishing level" : null,
                    ),

                    const SizedBox(height: 14),

                    // ✅ عرض الخطأ داخل الشاشة
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.red.withOpacity(0.25)),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
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
                            : const Text(
                                "Create Project",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

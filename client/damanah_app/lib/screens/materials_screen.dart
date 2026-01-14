import 'package:flutter/material.dart';

class MaterialsScreen extends StatefulWidget {
  final String projectId;
  const MaterialsScreen({super.key, required this.projectId});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final selected = <String>{};

  final Map<String, List<String>> materials = const {
    "Foundation": ["Concrete", "Rebar", "Gravel"],
    "Wall": ["Bricks", "Cinder Blocks", "Wood Studs"],
    "Flooring": ["Hardwood", "Tile", "Carpet"],
    "Roofing": ["Asphalt Shingles", "Metal Roofing", "Tile Roofing"],
    "Paint & Finishing": ["Interior Paint", "Exterior Paint", "Wood Stain"],
  };

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0E1814);
    const card = Color(0xFF2F463D);
    const green = Color(0xFF9EE7B7);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text("Materials"),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          ...materials.entries.map((cat) {
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: cat.value.map((m) {
                      final isOn = selected.contains(m);
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isOn) {
                              selected.remove(m);
                            } else {
                              selected.add(m);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isOn ? green.withOpacity(0.95) : Colors.white10,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isOn
                                  ? Colors.transparent
                                  : Colors.white.withOpacity(0.10),
                            ),
                          ),
                          child: Text(
                            m,
                            style: TextStyle(
                              color: isOn ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: selected.isEmpty ? null : () {
                // هون بعدين بنعمل Estimate API
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Selected: ${selected.join(', ')}"),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text("Continue"),
            ),
          ),
        ],
      ),
    );
  }
}

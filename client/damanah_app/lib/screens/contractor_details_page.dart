import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ContractorDetailsPage extends StatelessWidget {
  final Map<String, dynamic> contractor;
  const ContractorDetailsPage({super.key, required this.contractor});

  // ✅ تحويل رقم الهاتف لصيغة واتساب (الأردن 962)
  // مثال: 0778526859 -> 962778526859
  String _toWhatsAppPhone(String phone) {
    var p = phone.replaceAll(RegExp(r'\s+'), '').replaceAll('-', '');
    if (p.startsWith('0')) {
      p = '962${p.substring(1)}';
    }
    return p;
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0E1814);
    const card = Color(0xFF0F261F);

    final name = contractor["name"]?.toString() ?? "Contractor";
    final phone = (contractor["phone"] ?? "").toString().trim();
    final specialty =
        contractor["specialty"]?.toString() ??
        contractor["type"]?.toString() ??
        "General";
    final available = contractor["available"] == true;

    // ✅ City اختياري (إذا ما عندك بالباك اند ما رح يبين)
    final city = (contractor["city"] ?? "").toString().trim();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Contractor Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card.withOpacity(0.7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== Name =====
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),

                // ===== Status =====
                _row(
                  "Status",
                  _chip(
                    available ? "available" : "busy",
                    available ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                ),

                // ===== Phone + Buttons =====
                _row(
                  "Phone",
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          phone.isEmpty ? "-" : phone,
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 📋 Copy
                      _iconBtn(
                        icon: Icons.copy_rounded,
                        onTap: phone.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: phone),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Copied"),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                      ),
                      const SizedBox(width: 6),

                      // 📞 Call
                      _iconBtn(
                        icon: Icons.call_rounded,
                        onTap: phone.isEmpty
                            ? null
                            : () async {
                                final uri = Uri(scheme: 'tel', path: phone);
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                      ),
                      const SizedBox(width: 6),

                      // 💬 WhatsApp
                      _iconBtn(
                        icon: Icons.chat_rounded,
                        onTap: phone.isEmpty
                            ? null
                            : () async {
                                final waPhone = _toWhatsAppPhone(phone);
                                final uri = Uri.parse("https://wa.me/$waPhone");
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                      ),
                    ],
                  ),
                ),

                // ===== City (اختياري) =====
                if (city.isNotEmpty) _rowText("City", city),

                // ===== Specialty =====
                _rowText("Specialty", specialty),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= UI helpers =================

  Widget _row(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }

  Widget _rowText(String label, String value) {
    return _row(
      label,
      Text(
        value.isEmpty ? "-" : value,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _iconBtn({required IconData icon, required VoidCallback? onTap}) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(enabled ? 0.06 : 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: Colors.white.withOpacity(enabled ? 0.85 : 0.35),
        ),
      ),
    );
  }
}

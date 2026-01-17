import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'contractor_project_details_page.dart';

class ContractorNotificationsPage extends StatefulWidget {
  const ContractorNotificationsPage({super.key});

  @override
  State<ContractorNotificationsPage> createState() =>
      _ContractorNotificationsPageState();
}

class _ContractorNotificationsPageState
    extends State<ContractorNotificationsPage> {
  final _service = NotificationService();

  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];

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
      final list = await _service.getMyNotifications();
      setState(() => _items = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _asMap(dynamic x) {
    if (x is Map<String, dynamic>) return x;
    if (x is Map) return Map<String, dynamic>.from(x);
    return {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1814),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Messages",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.redAccent)),
                  )
                : _items.isEmpty
                    ? const Center(
                        child: Text("No notifications yet",
                            style: TextStyle(color: Colors.white70)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: Colors.white.withOpacity(0.06)),
                        itemBuilder: (context, i) {
                          final n = _asMap(_items[i]);
                          return _card(n);
                        },
                      ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> n) {
    final id = n["_id"]?.toString() ?? "";
    final title = n["title"]?.toString() ?? "Notification";
    final body = n["body"]?.toString() ?? "";
    final read = n["read"] == true;
    final projectId = n["projectId"]?.toString();

    Future<void> open() async {
      if (!read && id.isNotEmpty) {
        try {
          await _service.markAsRead(id);
          setState(() => n["read"] = true);
        } catch (_) {}
      }

      if (projectId != null && projectId.trim().isNotEmpty) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ContractorProjectDetailsPage(projectId: projectId),
          ),
        );
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: open,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F261F).withOpacity(0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: read
                    ? Colors.white.withOpacity(0.06)
                    : const Color(0xFF17362F).withOpacity(0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Icon(
                read ? Icons.notifications_none : Icons.notifications,
                color: Colors.white70,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                read ? FontWeight.w700 : FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (!read)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

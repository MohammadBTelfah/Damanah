import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'contractor_project_details_page.dart';

class ContractorNotificationsPage extends StatefulWidget {
  const ContractorNotificationsPage({super.key});

  @override
  State<ContractorNotificationsPage> createState() => _ContractorNotificationsPageState();
}

class _ContractorNotificationsPageState extends State<ContractorNotificationsPage> {
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

  // حذف إشعار واحد
  Future<void> _deleteItem(String id, int index) async {
    // حذف فوري من الواجهة (Optimistic UI)
    final deletedItem = _items[index];
    setState(() {
      _items.removeAt(index);
    });

    // استدعاء السيرفر
    final success = await _service.deleteNotification(id);

    if (!success) {
      // إذا فشل الحذف، نعيد العنصر للقائمة
      if (mounted) {
        setState(() {
          _items.insert(index, deletedItem);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete notification")),
        );
      }
    }
  }

  // حذف الكل
  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B3A35),
        title: const Text("Clear All?", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to delete all notifications?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Clear", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _items.clear()); // حذف فوري
      await _service.clearAll(); // طلب للسيرفر
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
      backgroundColor: const Color(0xFF0F261F), // نفس لون الخلفية الأساسي
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F261F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              onPressed: _clearAll,
              tooltip: "Clear All",
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF9EE7B7),
        backgroundColor: const Color(0xFF1B3A35),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF9EE7B7)))
            : _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 60, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        const Text("No notifications yet", style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final n = _asMap(_items[i]);
                      final id = n["_id"]?.toString() ?? "";
                      
                      // ✅ خاصية السحب للحذف
                      return Dismissible(
                        key: Key(id),
                        direction: DismissDirection.endToStart, // السحب من اليمين لليسار
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                        ),
                        onDismissed: (direction) {
                          _deleteItem(id, i);
                        },
                        child: _NotificationCard(
                          notification: n,
                          onRead: () async {
                            if (n["read"] != true && id.isNotEmpty) {
                              await _service.markAsRead(id);
                              setState(() => n["read"] = true);
                            }
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onRead;

  const _NotificationCard({required this.notification, required this.onRead});

  @override
  Widget build(BuildContext context) {
    final title = notification["title"]?.toString() ?? "Notification";
    final body = notification["body"]?.toString() ?? "";
    final read = notification["read"] == true;
    final type = notification["type"]?.toString() ?? "info";
    final projectId = notification["projectId"]?.toString();
    final createdAt = notification["createdAt"]?.toString() ?? "";

    // تحويل التاريخ لصيغة بسيطة
    String timeAgo = "";
    if (createdAt.isNotEmpty) {
      try {
        final date = DateTime.parse(createdAt);
        final diff = DateTime.now().difference(date);
        if (diff.inMinutes < 60) {
          timeAgo = "${diff.inMinutes}m ago";
        } else if (diff.inHours < 24) {
          timeAgo = "${diff.inHours}h ago";
        } else {
          timeAgo = "${diff.inDays}d ago";
        }
      } catch (_) {}
    }

    // تحديد الأيقونة واللون بناءً على النوع
    IconData icon = Icons.notifications;
    Color iconColor = const Color(0xFF9EE7B7);

    if (type == 'status_update') {
      icon = Icons.sync;
      iconColor = Colors.blueAccent;
    } else if (type == 'alert') {
      icon = Icons.warning_amber_rounded;
      iconColor = Colors.orangeAccent;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onRead(); // تعليم كمقروء
          if (projectId != null && projectId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ContractorProjectDetailsPage(projectId: projectId)),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: read ? const Color(0xFF1B3A35).withOpacity(0.5) : const Color(0xFF1B3A35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: read ? Colors.transparent : iconColor.withOpacity(0.5), // حدود ملونة للغير مقروء
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: read ? FontWeight.normal : FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (timeAgo.isNotEmpty)
                          Text(
                            timeAgo,
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!read) 
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 12),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
                )
            ],
          ),
        ),
      ),
    );
  }
}
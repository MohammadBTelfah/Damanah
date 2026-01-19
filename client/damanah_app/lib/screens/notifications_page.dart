import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'project_details_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
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

  // ✅ دالة حذف الكل
  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2C24),
        title: const Text("Clear All", style: TextStyle(color: Colors.white)),
        content: const Text("Delete all notifications?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Clear", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 1. حذف محلي فوري (لتجربة مستخدم سريعة)
      setState(() => _items.clear());

      try {
        // 2. ✅ استدعاء السيرفر للحذف الدائم
        await _service.clearAll();
      } catch (e) {
        // في حال فشل السيرفر، نعيد تحميل القائمة
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to clear on server: $e")),
          );
        }
      }
    }
  }

  // ✅ دالة حذف عنصر واحد (Swipe)
  void _deleteItem(int index) async {
    final item = _items[index];
    final id = item["_id"]?.toString();

    // 1. حذف من الشاشة فوراً
    setState(() {
      _items.removeAt(index);
    });

    // 2. ✅ حذف من السيرفر
    if (id != null) {
      try {
        await _service.deleteNotification(id);
      } catch (e) {
        debugPrint("Server delete failed: $e");
        // لا نزعج المستخدم برسالة خطأ هنا، لكن يمكن إعادة العنصر إذا أردت
      }
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
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              onPressed: _clearAll,
              tooltip: "Clear All",
              icon: const Icon(Icons.delete_sweep_outlined,
                  color: Colors.white70),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF9EE7B7),
        backgroundColor: const Color(0xFF1A2C24),
        onRefresh: _load,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF9EE7B7)))
            : _error != null
                ? _errorView()
                : _items.isEmpty
                    ? _emptyView()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final n = _asMap(_items[i]);
                          return _buildDismissibleCard(n, i);
                        },
                      ),
      ),
    );
  }

  // ✅ عنصر قابل للسحب (Dismissible)
  Widget _buildDismissibleCard(Map<String, dynamic> n, int index) {
    final id = n["_id"]?.toString() ?? UniqueKey().toString();

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteItem(index),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      child: _notificationCard(n),
    );
  }

  Widget _notificationCard(Map<String, dynamic> n) {
    final id = n["_id"]?.toString() ?? "";
    final title = n["title"]?.toString() ?? "Notification";
    final body = n["body"]?.toString() ?? "";
    final read = n["read"] == true;
    final projectId = n["projectId"]?.toString();
    final createdAt = n["createdAt"]?.toString();

    Future<void> open() async {
      // Mark as read instantly in UI
      if (!read) {
        setState(() => n["read"] = true);
        try {
          if (id.isNotEmpty) await _service.markAsRead(id);
        } catch (_) {}
      }

      // Navigate
      if (projectId != null && projectId.trim().isNotEmpty) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProjectDetailsPage(projectId: projectId),
          ),
        );
      }
    }

    return InkWell(
      onTap: open,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: read ? const Color(0xFF15221D) : const Color(0xFF1F3A30),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: read
                ? Colors.white.withOpacity(0.03)
                : const Color(0xFF9EE7B7).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            if (!read)
              BoxShadow(
                  color: const Color(0xFF9EE7B7).withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: read
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFF9EE7B7).withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                read
                    ? Icons.notifications_none_rounded
                    : Icons.notifications_active_rounded,
                color: read ? Colors.white54 : const Color(0xFF9EE7B7),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Content
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
                            color: read
                                ? Colors.white.withOpacity(0.9)
                                : Colors.white,
                            fontWeight:
                                read ? FontWeight.w600 : FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          _timeAgo(createdAt),
                          style: TextStyle(
                              color: read
                                  ? Colors.white30
                                  : const Color(0xFF9EE7B7),
                              fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: TextStyle(
                      color: read ? Colors.white54 : Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(String dateString) {
    try {
      final date = DateTime.parse(dateString).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) return "${diff.inDays}d ago";
      if (diff.inHours > 0) return "${diff.inHours}h ago";
      if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
      return "Just now";
    } catch (_) {
      return "";
    }
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 50, color: Colors.white38),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9EE7B7),
              foregroundColor: Colors.black,
            ),
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off_outlined,
                size: 48, color: Colors.white24),
          ),
          const SizedBox(height: 16),
          const Text("No notifications",
              style: TextStyle(color: Colors.white54, fontSize: 16)),
        ],
      ),
    );
  }
}
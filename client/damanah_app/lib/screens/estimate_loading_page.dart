import 'package:flutter/material.dart';

class EstimateLoadingPage extends StatelessWidget {
  final Future<void> Function() task;

  const EstimateLoadingPage({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    // شغّل التاسك أول ما الصفحة تنفتح
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await task();
        if (context.mounted) Navigator.pop(context, true); // success
      } catch (_) {
        if (context.mounted) Navigator.pop(context, false); // failed
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0E1814),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(height: 26),
              const Text(
                "Cost Estimation in\nprogress",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 22),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const LinearProgressIndicator(
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF31D39A)),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Please wait…",
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

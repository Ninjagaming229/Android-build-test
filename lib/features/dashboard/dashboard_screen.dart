// lib/features/dashboard/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/models/history_model.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../subtitle/subtitle_screen.dart';

// History provider
final historyProvider = FutureProvider<List<HistoryItem>>((ref) async {
  final api = ApiClient();
  final raw = await api.getHistory();
  return raw.map((e) => HistoryItem.fromJson(e as Map<String, dynamic>)).toList();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.video_camera_back, color: Color(0xFF3B82F6)),
            SizedBox(width: 8),
            Text('Recap Maker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF94A3B8)),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(historyProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick action card
              _buildActionCard(context),
              const SizedBox(height: 24),

              // History
              const Text(
                'ပြုလုပ်ပြီးသော Videos',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              historyAsync.when(
                data: (items) => items.isEmpty
                    ? _buildEmptyState()
                    : Column(children: items.map((item) => _buildHistoryCard(context, item)).toList()),
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
                error: (e, _) => _buildErrorState(e.toString()),
              ),
            ],
          ),
        ),
      ),

      // FAB to go to subtitle screen
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SubtitleScreen()),
        ),
        backgroundColor: const Color(0xFF1E40AF),
        icon: const Icon(Icons.closed_caption, color: Colors.white),
        label: const Text('Subtitle ထည့်မည်', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF3730A3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎬 Video Subtitle ထည့်မည်',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Video upload လုပ်ပြီး subtitle ရွေးချယ်မှုများ ပြင်ဆင်ပါ',
            style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubtitleScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1E40AF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('စတင်မည်', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, HistoryItem item) {
    final api = ApiClient();
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (item.status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'ပြီးဆုံးပြီ';
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'မအောင်မြင်ပါ';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = 'Processing...';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Job: ${item.jobId.substring(0, 8)}...',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  item.createdAt,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
              ],
            ),
          ),
          if (item.isCompleted && item.secondsLeft > 0)
            TextButton(
              onPressed: () {
                final url = api.getDownloadUrl(item.filePath);
                _showDownloadDialog(context, url);
              },
              child: const Text('Download', style: TextStyle(color: Color(0xFF3B82F6))),
            ),
        ],
      ),
    );
  }

  void _showDownloadDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Download Link', style: TextStyle(color: Colors.white)),
        content: SelectableText(url, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: const [
            Icon(Icons.history, color: Color(0xFF334155), size: 64),
            SizedBox(height: 16),
            Text('History မရှိသေးပါ', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange, size: 48),
            const SizedBox(height: 12),
            Text('Error: $error', style: const TextStyle(color: Color(0xFF94A3B8)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

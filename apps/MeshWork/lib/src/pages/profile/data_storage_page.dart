import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_storage/ebi_storage.dart';

/// Data & Storage settings page – shows cache stats and clear actions.
class DataStoragePage extends ConsumerWidget {
  const DataStoragePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheStats = ref.watch(cacheStatsProvider);

    return Scaffold(
      appBar: EbiAppBar(title: ref.L('DataAndStorage')),
      body: ListView(
        children: [
          const SizedBox(height: 16),

          // Cache stats
          cacheStats.when(
            data: (stats) => Column(
              children: [
                _infoTile(context, ref.L('Messages'), '${stats.messageCount}'),
                _infoTile(
                    context, ref.L('Conversations'), '${stats.conversationCount}'),
                _infoTile(context, 'Database', stats.formattedSize),
              ],
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const Divider(height: 32),

          // Clear actions
          _actionTile(
            context,
            icon: Icons.image_outlined,
            title: ref.L('ClearImageCache'),
            onTap: () => _clearImageCache(context, ref),
          ),
          _actionTile(
            context,
            icon: Icons.delete_outline,
            title: ref.L('ClearChatHistory'),
            onTap: () => _clearAllCache(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(BuildContext context, String title, String value) {
    return ListTile(
      title: Text(title, style: EbiTextStyles.bodyLarge),
      trailing: Text(value, style: EbiTextStyles.bodySmall),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: EbiColors.primaryBlue),
      title: Text(title, style: EbiTextStyles.bodyLarge),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<void> _clearImageCache(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.L('Confirm')),
        content: const Text('Clear all cached images?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ref.L('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ref.L('Confirm')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      ref.invalidate(cacheStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.L('Success'))),
        );
      }
    }
  }

  Future<void> _clearAllCache(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.L('Confirm')),
        content: const Text(
            'Clear all local cache? Chat history will be re-downloaded from server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ref.L('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              ref.L('Delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final db = ref.read(databaseProvider);
        await db.clearAllData();
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        ref.invalidate(cacheStatsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ref.L('Success'))),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${ref.L('Error')}: $e')),
          );
        }
      }
    }
  }
}

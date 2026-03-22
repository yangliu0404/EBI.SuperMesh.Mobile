import 'package:ebi_storage/ebi_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple draft service using app_cache table.
///
/// Drafts are stored with key format `draft:{roomId}`.
class DraftService {
  final AppCacheDao _cacheDao;

  DraftService(this._cacheDao);

  /// Save draft text for a conversation.
  Future<void> saveDraft(String roomId, String text) async {
    if (text.trim().isEmpty) {
      await _cacheDao.remove('draft:$roomId');
      return;
    }
    await _cacheDao.put('draft:$roomId', text);
  }

  /// Load draft text for a conversation.
  Future<String?> loadDraft(String roomId) async {
    return _cacheDao.get('draft:$roomId');
  }

  /// Clear draft for a conversation.
  Future<void> clearDraft(String roomId) async {
    await _cacheDao.remove('draft:$roomId');
  }
}

/// Provider for [DraftService]. Returns null if DB is not initialized.
final draftServiceProvider = Provider<DraftService?>((ref) {
  try {
    final cacheDao = ref.read(appCacheDaoProvider);
    return DraftService(cacheDao);
  } catch (_) {
    return null;
  }
});

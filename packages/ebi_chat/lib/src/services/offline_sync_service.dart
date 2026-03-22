import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_storage/ebi_storage.dart';
import 'package:ebi_chat/src/models/im_models.dart';
import 'package:ebi_chat/src/repository/signalr_chat_repository.dart';

/// Manages offline message queue and retries on network recovery.
class OfflineSyncService {
  final MessageDao _messageDao;
  final SignalRChatRepository _repo;
  StreamSubscription? _connectivitySub;

  OfflineSyncService({
    required MessageDao messageDao,
    required SignalRChatRepository repo,
  })  : _messageDao = messageDao,
        _repo = repo;

  /// Start listening for network changes and retry pending messages.
  void start() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        retryPendingMessages();
      }
    });
  }

  /// Retry all pending messages (syncState = 1 or 2).
  Future<void> retryPendingMessages() async {
    try {
      final pending = await _messageDao.getPendingSend();
      if (pending.isEmpty) return;

      AppLogger.info(
          '[OfflineSync] Retrying ${pending.length} pending messages');

      for (final msg in pending) {
        try {
          final imMsg = ImChatMessage(
            messageId: msg.messageId,
            tenantId: msg.tenantId,
            groupId: msg.groupId,
            formUserId: msg.formUserId,
            formUserName: msg.formUserName,
            toUserId: msg.toUserId,
            content: msg.content,
            sendTime: msg.sendTime,
            messageType: msg.messageType,
            source: msg.source,
            state: msg.state,
            extraProperties: msg.extraProperties != null
                ? (jsonDecode(msg.extraProperties!) as Map<String, dynamic>)
                : null,
          );

          await _repo.sendMessage(imMsg);
          // sendMessage already updates syncState on success
        } catch (e) {
          AppLogger.warning(
              '[OfflineSync] Retry failed for ${msg.messageId}: $e');
          await _messageDao.updateSyncState(msg.messageId, 2); // sendFailed
        }
      }
    } catch (e) {
      AppLogger.error('[OfflineSync] retryPendingMessages failed', e);
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}

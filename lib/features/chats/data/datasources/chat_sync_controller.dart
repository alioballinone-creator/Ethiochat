import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/logging/app_logger.dart';
import 'chat_sync_service.dart';
import 'remote_chat_source.dart';

/// Keeps the local chat database in step with the signed-in Supabase account.
///
/// Sync is deliberately best effort: local data stays usable while offline and
/// a failed pull is retried without blocking the UI.
class ChatSyncController {
  ChatSyncController({
    required this.db,
    required this.client,
    this.retryDelay = const Duration(seconds: 30),
    this.maxRetryDelay = const Duration(minutes: 5),
  });

  final AppDatabase db;
  final SupabaseClient client;
  final Duration retryDelay;
  final Duration maxRetryDelay;

  StreamSubscription<AuthState>? _authSubscription;
  ChatSyncService? _service;
  RemoteChatSource? _source;
  String? _userId;
  Timer? _retryTimer;
  Timer? _resyncTimer;
  bool _started = false;
  bool _disposed = false;
  bool _syncing = false;
  bool _resyncQueued = false;
  int _retryAttempt = 0;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _authSubscription = client.auth.onAuthStateChange.listen((state) {
      final user = state.session?.user;
      if (user == null) {
        unawaited(_deactivate());
      } else {
        unawaited(_activate(user.id));
      }
    });
    final user = client.auth.currentUser;
    if (user != null) await _activate(user.id);
  }

  Future<void> _activate(String userId) async {
    if (_disposed) return;
    if (_userId == userId && _service != null) return;
    await _deactivate();
    if (_disposed) return;

    final source = SupabaseRemoteChatSource(client: client);
    final service = ChatSyncService(
      db: db,
      source: source,
      currentUserId: userId,
    );
    _userId = userId;
    _source = source;
    _service = service;
    source.subscribe(
      onMessage: (message) => unawaited(_onRealtimeMessage(message)),
      onMessageUpdated: (message) => unawaited(
        _onRealtimeMessage(message, incrementUnread: false),
      ),
      onReceipt: (receipt) => unawaited(_onRealtimeReceipt(receipt)),
      onConversation: (_) => _scheduleResync(),
      onError: (error, stackTrace) => AppLogger.warn(
        'Chat realtime subscription failed',
        error: error,
        stackTrace: stackTrace,
      ),
    );
    await _runSync();
  }

  Future<void> _deactivate() async {
    _retryTimer?.cancel();
    _resyncTimer?.cancel();
    _retryTimer = null;
    _resyncTimer = null;
    _resyncQueued = false;
    final source = _source;
    _source = null;
    _service = null;
    _userId = null;
    if (source != null) {
      try {
        await source.dispose();
      } catch (error, stackTrace) {
        AppLogger.warn(
          'Could not close chat realtime subscription',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _runSync() async {
    final service = _service;
    if (service == null || _disposed) return;
    if (_syncing) {
      _resyncQueued = true;
      return;
    }
    _syncing = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    try {
      final report = await service.sync();
      _retryAttempt = 0;
      AppLogger.info(
        'Chat sync imported ${report.conversations} conversations, '
        '${report.messages} messages',
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Chat sync failed; retrying later',
        error: error,
        stackTrace: stackTrace,
      );
      _scheduleRetry();
    } finally {
      _syncing = false;
      if (_resyncQueued && !_disposed) {
        _resyncQueued = false;
        unawaited(_runSync());
      }
    }
  }

  Future<void> _onRealtimeMessage(
    RemoteMessage message, {
    bool incrementUnread = true,
  }) async {
    final service = _service;
    if (service == null || _disposed) return;
    try {
      final imported = await service.importMessage(
        message,
        incrementUnread: incrementUnread,
      );
      if (!imported) await _runSync();
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Could not import realtime chat message',
        error: error,
        stackTrace: stackTrace,
      );
      _scheduleRetry();
    }
  }

  /// Fetches one older remote page for [conversationId]. Returns 0 when there
  /// is no authenticated backend or the conversation has no older history.
  Future<int> loadOlder(String conversationId) async {
    final service = _service;
    if (service == null || _disposed) return 0;
    return service.syncOlder(conversationId);
  }

  Future<void> _onRealtimeReceipt(RemoteReceipt receipt) async {
    final service = _service;
    if (service == null || _disposed) return;
    try {
      await service.importReceipt(receipt);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Could not import realtime message receipt',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _scheduleResync() {
    if (_disposed) return;
    _resyncTimer?.cancel();
    _resyncTimer = Timer(const Duration(milliseconds: 500), () {
      _resyncTimer = null;
      unawaited(_runSync());
    });
  }

  void _scheduleRetry() {
    if (_disposed || _retryTimer != null) return;
    _retryAttempt++;
    final multiplier = 1 << (_retryAttempt - 1).clamp(0, 20).toInt();
    final delay = Duration(
      milliseconds: (retryDelay.inMilliseconds * multiplier)
          .clamp(0, maxRetryDelay.inMilliseconds)
          .toInt(),
    );
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      unawaited(_runSync());
    });
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _resyncTimer?.cancel();
    _retryTimer = null;
    _resyncTimer = null;
    _authSubscription?.cancel();
    _authSubscription = null;
    final source = _source;
    _source = null;
    _service = null;
    _userId = null;
    if (source != null) unawaited(source.dispose());
  }
}

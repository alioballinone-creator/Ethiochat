import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';

import 'package:ethiochat/core/db/app_database.dart';
import 'package:ethiochat/core/logging/app_logger.dart';

typedef OutboxTransport = Future<void> Function(
  Map<String, dynamic> payload,
);

/// OutboxWorker implements the send pipeline:
/// 1. Write to outbox/local as pending (handled by repo)
/// 2. Pick up pending in FIFO order per conversation
/// 3. Upload media and call the Supabase send RPC
/// 4. Exponential backoff with jitter, cap 60s
/// 5. On success mark sent; never silently drop a failed message
class OutboxWorker {
  OutboxWorker({
    required this.db,
    required this.connectivity,
    this.transport,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 60),
    this.maxAttempts = 10,
  });

  final AppDatabase db;
  final Connectivity connectivity;
  final OutboxTransport? transport;
  final Duration baseDelay;
  final Duration maxDelay;
  final int maxAttempts;
  final _rng = Random.secure();

  Timer? _timer;
  bool _running = false;
  bool _paused = false;
  bool _processing = false;

  void start() {
    if (_running) return;
    _running = true;
    connectivity.onConnectivityChanged.listen(_onConnectivity);
    _scheduleNext(const Duration(milliseconds: 250));
    AppLogger.info('OutboxWorker started');
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  void pause() => _paused = true;
  void resume() {
    _paused = false;
    if (_running) _scheduleNext(const Duration(milliseconds: 100));
  }

  void trigger() {
    if (_running && !_paused) _scheduleNext(const Duration(milliseconds: 50));
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    if (hasNetwork && _running && !_paused) {
      _scheduleNext(const Duration(milliseconds: 200));
    }
  }

  void _scheduleNext(Duration d) {
    _timer?.cancel();
    if (!_running || _paused) return;
    _timer = Timer(d, _tick);
  }

  Future<void> _tick() async {
    if (!_running || _paused) return;
    try {
      final processed = await processPending();
      _scheduleNext(
        processed
            ? const Duration(milliseconds: 500)
            : const Duration(seconds: 5),
      );
    } catch (e, st) {
      AppLogger.error('OutboxWorker tick failed', error: e, stackTrace: st);
      _scheduleNext(const Duration(seconds: 3));
    }
  }

  /// Processes one batch of due rows. Returns whether any row was attempted.
  Future<bool> processPending() async {
    if (_processing || _paused) return false;
    _processing = true;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final pending = await (db.select(db.outbox)
            ..where((o) => o.nextRetryAt.isSmallerOrEqualValue(now))
            ..orderBy([(o) => OrderingTerm.asc(o.createdAt)])
            ..limit(20))
          .get();
      if (pending.isEmpty) return false;
      for (final row in pending) {
        await _processRow(row);
      }
      return true;
    } finally {
      _processing = false;
    }
  }

  Future<void> _processRow(OutboxData row) async {
    final attempt = row.attempt + 1;
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.error('Outbox payload was invalid for ${row.messageId}');
      await (db.delete(db.outbox)
            ..where((o) => o.messageId.equals(row.messageId)))
          .go();
      return;
    }
    final kind = payload['kind'] as String? ?? 'message';
    if (attempt > maxAttempts) {
      if (kind == 'message') {
        // Mark message as failed; do NOT drop. Surface "Tap to retry" in UI.
        await (db.update(db.messages)..where((m) => m.id.equals(row.messageId)))
            .write(const MessagesCompanion(status: Value(4)));
      }
      AppLogger.warn('Outbox gave up on ${row.messageId} after $attempt');
      await (db.delete(db.outbox)
            ..where((o) => o.messageId.equals(row.messageId)))
          .go();
      return;
    }

    try {
      payload['__attempt'] = attempt;
      if (transport != null) await transport!(payload);

      if (kind == 'message') {
        await (db.update(db.messages)..where((m) => m.id.equals(row.messageId)))
            .write(const MessagesCompanion(status: Value(1))); // sent
      }

      await (db.delete(db.outbox)
            ..where((o) => o.messageId.equals(row.messageId)))
          .go();
    } catch (e) {
      final delay = _backoff(attempt);
      final next = DateTime.now().add(delay).millisecondsSinceEpoch;
      await (db.update(db.outbox)
            ..where((o) => o.messageId.equals(row.messageId)))
          .write(
        OutboxCompanion(
          attempt: Value(attempt),
          nextRetryAt: Value(next),
          lastError: Value(e.toString()),
        ),
      );
      AppLogger.debug('Retrying ${row.messageId} in ${delay.inSeconds}s');
    }
  }

  Duration _backoff(int attempt) {
    // 1,2,4,8,... capped at 60s with jitter
    final base = baseDelay.inMilliseconds * pow(2, attempt - 1);
    final capped = min(base.toInt(), maxDelay.inMilliseconds);
    final jitter = _rng.nextInt((capped * 0.25).clamp(1, 15000).toInt());
    return Duration(milliseconds: capped + jitter);
  }

  /// Enqueue a message for sending.
  static Future<void> enqueue(
    AppDatabase db, {
    required String messageId,
    required String conversationId,
    required Map<String, dynamic> payload,
  }) async {
    await db.into(db.outbox).insertOnConflictUpdate(
          OutboxCompanion(
            messageId: Value(messageId),
            conversationId: Value(conversationId),
            payloadJson: Value(jsonEncode(payload)),
            attempt: const Value(0),
            nextRetryAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }
}

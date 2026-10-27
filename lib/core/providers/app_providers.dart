import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/chats/data/datasources/chat_sync_controller.dart';
import '../../features/chats/data/datasources/outbox_worker.dart';
import '../../features/chats/data/datasources/supabase_outbox_transport.dart';
import '../config/env.dart';
import '../db/app_database.dart';
import '../network/connectivity_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Background send pipeline. Starting it here guarantees queued messages are
/// retried even when the user never opens the chat list.
final outboxWorkerProvider = Provider<OutboxWorker>((ref) {
  final worker = OutboxWorker(
    db: ref.watch(appDatabaseProvider),
    connectivity: Connectivity(),
    transport: SupabaseOutboxTransport().send,
  );
  worker.start();
  ref.onDispose(worker.stop);
  return worker;
});

/// Pulls authenticated conversations/messages and keeps realtime inserts in
/// sync with the local database. Returns null for credential-free demo builds.
final chatSyncProvider = Provider<ChatSyncController?>((ref) {
  if (!Env.hasSupabase) return null;
  final controller = ChatSyncController(
    db: ref.watch(appDatabaseProvider),
    client: Supabase.instance.client,
  );
  unawaited(controller.start());
  ref.onDispose(controller.dispose);
  return controller;
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService(connectivity: Connectivity());
  service.start();
  ref.onDispose(service.dispose);
  return service;
});

final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.stream;
});

final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(networkStatusProvider);
  return status.maybeWhen(
    data: (s) => s != NetworkStatus.offline,
    orElse: () => true,
  );
});

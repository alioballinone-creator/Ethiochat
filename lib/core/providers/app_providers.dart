import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../network/connectivity_service.dart';
import '../../features/chats/data/datasources/outbox_worker.dart';
import '../../features/chats/data/datasources/supabase_outbox_transport.dart';

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

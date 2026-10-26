import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../network/connectivity_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService(connectivity: Connectivity());
  service.start();
  ref.onDispose(() => service.dispose());
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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../data/wallet_pin_store.dart';
import '../data/wallet_repository.dart';
import '../domain/entities/wallet_entry.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(appDatabaseProvider));
});

final walletSeedProvider = FutureProvider<void>((ref) {
  return ref.watch(walletRepositoryProvider).seedDemoData();
});

final walletBalanceProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(walletRepositoryProvider).watchBalance();
});

final walletEntriesProvider = StreamProvider.autoDispose<List<WalletEntry>>(
  (ref) => ref.watch(walletRepositoryProvider).watchEntries(),
);

final walletPinStoreProvider = Provider<WalletPinStore>((ref) {
  return WalletPinStore();
});

final walletHasPinProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(walletPinStoreProvider).hasPin();
});

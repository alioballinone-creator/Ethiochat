import 'package:drift/native.dart';
import 'package:ethiochat/core/db/app_database.dart';
import 'package:ethiochat/features/wallet/data/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late WalletRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = WalletRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('money actions fail closed without an authenticated server', () async {
    final results = [
      await repository.sendMoney(
        recipient: 'recipient-id',
        amountMinor: 100,
      ),
      await repository.payBill(
        provider: 'Utility',
        accountRef: 'account-1',
        amountMinor: 100,
      ),
      await repository.sendRedPacket(
        totalMinor: 100,
        count: 1,
        note: 'Test',
      ),
      await repository.topUp(
        amountMinor: 100,
        provider: 'Provider',
      ),
      await repository.receive(sender: 'Friend', amountMinor: 0),
      await repository.purchase(
        amountMinor: 100,
        provider: 'Shop',
      ),
    ];

    expect(results.every((result) => result.failureOrNull != null), isTrue);
    expect(await database.select(database.ledgerEntries).get(), isEmpty);
    expect(await database.select(database.walletTransactions).get(), isEmpty);
  });
}

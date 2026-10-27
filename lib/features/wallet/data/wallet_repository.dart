import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../domain/entities/wallet_entry.dart';

class WalletRepository {
  WalletRepository(this.db);

  final AppDatabase db;
  final _uuid = const Uuid();

  Stream<int> watchBalance() {
    return (db.select(db.ledgerEntries)..where((e) => e.account.equals('me')))
        .watch()
        .map(_balanceOf);
  }

  Future<int> currentBalance() async {
    final rows = await (db.select(db.ledgerEntries)
          ..where((e) => e.account.equals('me')))
        .get();
    return _balanceOf(rows);
  }

  int _balanceOf(List<LedgerEntry> rows) {
    return rows.fold<int>(
      0,
      (sum, row) =>
          sum +
          (row.direction == 'credit' ? row.amountMinor : -row.amountMinor),
    );
  }

  Stream<List<WalletEntry>> watchEntries() {
    return (db.select(db.walletTransactions)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(100))
        .watch()
        .map((rows) => rows.map(_toEntity).toList(growable: false));
  }

  WalletEntry _toEntity(WalletTransaction row) {
    return WalletEntry(
      id: row.id,
      type: WalletTxType.values.firstWhere(
        (type) => type.name == row.type,
        orElse: () => WalletTxType.transfer,
      ),
      direction: row.direction == 'in'
          ? WalletDirection.incoming
          : WalletDirection.outgoing,
      amountMinor: row.amountMinor,
      status: row.status,
      createdAt: row.createdAt,
      counterparty: row.counterparty,
      note: row.note,
    );
  }

  Future<Result<WalletTransaction>> sendMoney({
    required String recipient,
    required int amountMinor,
    String? note,
    String? idempotencyKey,
  }) {
    return _debit(
      type: WalletTxType.transfer,
      amountMinor: amountMinor,
      counterparty: recipient,
      note: note,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Result<WalletTransaction>> payBill({
    required String provider,
    required String accountRef,
    required int amountMinor,
    int feeMinor = 0,
    String? idempotencyKey,
  }) {
    return _debit(
      type: WalletTxType.bill,
      amountMinor: amountMinor + feeMinor,
      counterparty: provider,
      note: 'Account $accountRef',
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Result<WalletTransaction>> sendRedPacket({
    required int totalMinor,
    required int count,
    required String note,
    String? idempotencyKey,
  }) {
    return _debit(
      type: WalletTxType.redPacket,
      amountMinor: totalMinor,
      counterparty: 'Red packet · $count ${count == 1 ? 'person' : 'people'}',
      note: note,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Result<WalletTransaction>> topUp({
    required int amountMinor,
    required String provider,
    String? idempotencyKey,
  }) async {
    if (amountMinor <= 0) {
      return const Result.failure(
        ValidationFailure('Enter an amount greater than zero.'),
      );
    }
    return _post(
      type: WalletTxType.topUp,
      amountMinor: amountMinor,
      incoming: true,
      counterparty: provider,
      note: 'Top up',
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Result<WalletTransaction>> receive({
    required String sender,
    required int amountMinor,
    String? note,
    String? idempotencyKey,
  }) {
    return _post(
      type: WalletTxType.receive,
      amountMinor: amountMinor,
      incoming: true,
      counterparty: sender,
      note: note,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Result<WalletTransaction>> _debit({
    required WalletTxType type,
    required int amountMinor,
    required String counterparty,
    String? note,
    String? idempotencyKey,
  }) async {
    if (amountMinor <= 0) {
      return const Result.failure(
        ValidationFailure('Enter an amount greater than zero.'),
      );
    }
    final balance = await currentBalance();
    if (amountMinor > balance) {
      return const Result.failure(
        ValidationFailure('Your wallet balance is too low.'),
      );
    }
    return _post(
      type: type,
      amountMinor: amountMinor,
      incoming: false,
      counterparty: counterparty,
      note: note,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Result<WalletTransaction>> _post({
    required WalletTxType type,
    required int amountMinor,
    required bool incoming,
    required String counterparty,
    String? note,
    String? idempotencyKey,
  }) async {
    try {
      final key = idempotencyKey ?? _uuid.v4();
      final existing = await (db.select(db.walletTransactions)
            ..where((t) => t.idempotencyKey.equals(key)))
          .getSingleOrNull();
      if (existing != null) {
        return Result.success(existing);
      }

      final txnId = _uuid.v4();
      final meEntry = _uuid.v4();
      final systemEntry = _uuid.v4();
      final now = DateTime.now();
      final systemAccount = 'system:${type.name}';

      await db.transaction(() async {
        await db.into(db.walletTransactions).insert(
              WalletTransactionsCompanion.insert(
                id: txnId,
                type: type.name,
                amountMinor: amountMinor,
                direction: incoming ? 'in' : 'out',
                counterparty: Value(counterparty),
                note: Value(note),
                idempotencyKey: Value(key),
                createdAt: Value(now),
              ),
            );
        await db.into(db.ledgerEntries).insert(
              LedgerEntriesCompanion.insert(
                id: meEntry,
                txnId: txnId,
                account: 'me',
                direction: incoming ? 'credit' : 'debit',
                amountMinor: amountMinor,
                createdAt: Value(now),
              ),
            );
        await db.into(db.ledgerEntries).insert(
              LedgerEntriesCompanion.insert(
                id: systemEntry,
                txnId: txnId,
                account: systemAccount,
                direction: incoming ? 'debit' : 'credit',
                amountMinor: amountMinor,
                createdAt: Value(now),
              ),
            );
      });

      final row = await (db.select(db.walletTransactions)
            ..where((t) => t.id.equals(txnId)))
          .getSingle();
      return Result.success(row);
    } catch (error) {
      return Result.failure(mapError(error));
    }
  }

  Future<void> seedDemoData() async {
    final count = await (db.select(db.walletTransactions)).get();
    if (count.isNotEmpty) return;
    final now = DateTime.now();
    await _seedEntry(
      type: WalletTxType.topUp,
      amountMinor: 50000,
      incoming: true,
      counterparty: 'Telebirr',
      note: 'Wallet top up',
      at: now.subtract(const Duration(hours: 20)),
      id: 'seed-wallet-topup',
    );
    await _seedEntry(
      type: WalletTxType.receive,
      amountMinor: 80000,
      incoming: true,
      counterparty: 'Hanna Girma',
      note: 'Dinner split',
      at: now.subtract(const Duration(hours: 8)),
      id: 'seed-wallet-receive',
    );
    await _seedEntry(
      type: WalletTxType.bill,
      amountMinor: 4950,
      incoming: false,
      counterparty: 'Ethio Telecom',
      note: 'Airtime bundle',
      at: now.subtract(const Duration(hours: 2)),
      id: 'seed-wallet-bill',
    );
  }

  Future<void> _seedEntry({
    required WalletTxType type,
    required int amountMinor,
    required bool incoming,
    required String counterparty,
    required String note,
    required DateTime at,
    required String id,
  }) async {
    await db.transaction(() async {
      await db.into(db.walletTransactions).insert(
            WalletTransactionsCompanion.insert(
              id: id,
              type: type.name,
              amountMinor: amountMinor,
              direction: incoming ? 'in' : 'out',
              counterparty: Value(counterparty),
              note: Value(note),
              createdAt: Value(at),
            ),
          );
      await db.into(db.ledgerEntries).insert(
            LedgerEntriesCompanion.insert(
              id: '$id-me',
              txnId: id,
              account: 'me',
              direction: incoming ? 'credit' : 'debit',
              amountMinor: amountMinor,
              createdAt: Value(at),
            ),
          );
      await db.into(db.ledgerEntries).insert(
            LedgerEntriesCompanion.insert(
              id: '$id-system',
              txnId: id,
              account: 'system:${type.name}',
              direction: incoming ? 'debit' : 'credit',
              amountMinor: amountMinor,
              createdAt: Value(at),
            ),
          );
    });
  }
}

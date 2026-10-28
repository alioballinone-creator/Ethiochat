import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/env.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../domain/entities/wallet_entry.dart';

class WalletRepository {
  WalletRepository(this.db, {SupabaseClient? client}) : _client = client;

  final AppDatabase db;
  final SupabaseClient? _client;
  final _uuid = const Uuid();

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Stream<int> watchBalance() {
    if (Env.hasSupabase && _supabase.auth.currentUser != null) {
      // The server is the source of truth. Fall back to local ledger only when
      // unauthenticated or offline so the UI remains usable without minting
      // fake funds.
    }
    return (db.select(db.ledgerEntries)..where((e) => e.account.equals('me')))
        .watch()
        .map(_balanceOf);
  }

  Future<int> currentBalance() async {
    if (Env.hasSupabase && _supabase.auth.currentUser != null) {
      try {
        final rows = await _supabase
            .from('ledger_entries')
            .select('direction,amount_minor')
            .eq('account', _supabase.auth.currentUser!.id);
        var balance = 0;
        for (final row in rows) {
          final amount = (row['amount_minor'] as num?)?.toInt() ?? 0;
          if (row['direction'] == 'credit') {
            balance += amount;
          } else {
            balance -= amount;
          }
        }
        return balance;
      } catch (_) {
        // Fall back to local cache on network errors.
      }
    }
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
    String? pin,
    String? idempotencyKey,
  }) async {
    if (amountMinor <= 0) {
      return const Result.failure(
        ValidationFailure('Enter an amount greater than zero.'),
      );
    }
    if (Env.hasSupabase && _supabase.auth.currentUser != null) {
      if (pin == null || pin.isEmpty) {
        return const Result.failure(ValidationFailure('Enter your wallet PIN.'));
      }
      try {
        final id = idempotencyKey ?? _uuid.v4();
        await _supabase.functions.invoke(
          'wallet-transfer',
          body: {
            'recipientId': recipient,
            'amountMinor': amountMinor,
            'pin': pin,
            'note': note,
            'idempotencyKey': id,
          },
        );
        final row = await (db.select(db.walletTransactions)
              ..where((t) => t.idempotencyKey.equals(id)))
            .getSingleOrNull();
        if (row != null) return Result.success(row);
        await _localRecord(
          type: WalletTxType.transfer,
          amountMinor: amountMinor,
          incoming: false,
          counterparty: recipient,
          note: note,
          idempotencyKey: id,
        );
        final stored = await (db.select(db.walletTransactions)
              ..where((t) => t.idempotencyKey.equals(id)))
            .getSingle();
        return Result.success(stored);
      } catch (error) {
        return Result.failure(mapError(error));
      }
    }
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
    String? pin,
    String? idempotencyKey,
  }) async {
    final total = amountMinor + feeMinor;
    if (total <= 0) {
      return const Result.failure(
        ValidationFailure('Enter an amount greater than zero.'),
      );
    }
    // Bills are processed by the configured provider; without a server
    // integration this build fails closed rather than fabricating a successful
    // payment.
    if (Env.hasSupabase && _supabase.auth.currentUser != null) {
      return const Result.failure(
        ValidationFailure(
          'Bill payments are not configured for this build.',
        ),
      );
    }
    return _debit(
      type: WalletTxType.bill,
      amountMinor: total,
      counterparty: provider,
      note: 'Account $accountRef',
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Result<WalletTransaction>> sendRedPacket({
    required int totalMinor,
    required int count,
    required String note,
    String? conversationId,
    String? pin,
    String? idempotencyKey,
  }) async {
    if (totalMinor <= 0 || count <= 0) {
      return const Result.failure(
        ValidationFailure('Enter a valid red packet amount.'),
      );
    }
    if (Env.hasSupabase && _supabase.auth.currentUser != null) {
      if (pin == null || pin.isEmpty) {
        return const Result.failure(
            ValidationFailure('Enter your wallet PIN.'));
      }
      try {
        final id = idempotencyKey ?? _uuid.v4();
        await _supabase.functions.invoke(
          'wallet-redpacket',
          body: {
            'action': 'create',
            'conversationId': conversationId,
            'totalMinor': totalMinor,
            'count': count,
            'mode': 'random',
            'pin': pin,
            'idempotencyKey': id,
          },
        );
        await _localRecord(
          type: WalletTxType.redPacket,
          amountMinor: totalMinor,
          incoming: false,
          counterparty:
              'Red packet · $count ${count == 1 ? 'person' : 'people'}',
          note: note,
          idempotencyKey: id,
        );
        final stored = await (db.select(db.walletTransactions)
              ..where((t) => t.idempotencyKey.equals(id)))
            .getSingleOrNull();
        if (stored != null) return Result.success(stored);
        await _localRecord(
          type: WalletTxType.redPacket,
          amountMinor: totalMinor,
          incoming: false,
          counterparty:
              'Red packet · $count ${count == 1 ? 'person' : 'people'}',
          note: note,
          idempotencyKey: id,
        );
        final again = await (db.select(db.walletTransactions)
              ..where((t) => t.idempotencyKey.equals(id)))
            .getSingle();
        return Result.success(again);
      } catch (error) {
        return Result.failure(mapError(error));
      }
    }
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
    // Payment provider integration is not configured in this build. The
    // repository never fabricates provider callbacks or a "successful" charge.
    if (Env.hasSupabase && _supabase.auth.currentUser != null) {
      return const Result.failure(
        ValidationFailure(
          'Top-up is not configured for this build. Add a provider webhook or '
          'use an approved test path.',
        ),
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
  }) async {
    if (amountMinor <= 0) {
      return const Result.failure(
        ValidationFailure('Enter an amount greater than zero.'),
      );
    }
    if (Env.hasSupabase && _supabase.auth.currentUser != null) {
      // Requesting money creates a shareable intent; it is not a credit. Credits
      // only occur on the server after an authenticated payer completes a
      // verified transfer.
      try {
        final row = await _localRecord(
          type: WalletTxType.receive,
          amountMinor: amountMinor,
          incoming: true,
          counterparty: sender,
          note: note ?? 'Payment request',
          idempotencyKey: idempotencyKey ?? _uuid.v4(),
          pending: true,
        );
        return Result.success(row);
      } catch (error) {
        return Result.failure(mapError(error));
      }
    }
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

  Future<WalletTransaction> _localRecord({
    required WalletTxType type,
    required int amountMinor,
    required bool incoming,
    required String counterparty,
    String? note,
    String? idempotencyKey,
    bool pending = false,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    final existing = await (db.select(db.walletTransactions)
          ..where((t) => t.idempotencyKey.equals(key)))
        .getSingleOrNull();
    if (existing != null) return existing;

    final txnId = _uuid.v4();
    final now = DateTime.now();
    await db.into(db.walletTransactions).insert(
          WalletTransactionsCompanion.insert(
            id: txnId,
            type: type.name,
            amountMinor: amountMinor,
            direction: incoming ? 'in' : 'out',
            counterparty: Value(counterparty),
            note: Value(pending ? '[pending] ${note ?? ''}'.trim() : note),
            status: Value(pending ? 'pending' : 'success'),
            idempotencyKey: Value(key),
            createdAt: Value(now),
          ),
        );
    return (db.select(db.walletTransactions)..where((t) => t.id.equals(txnId)))
        .getSingle();
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

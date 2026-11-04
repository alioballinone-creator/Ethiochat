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
    final userId = _authenticatedUserId;
    if (userId == null) return Stream<int>.value(0);
    return _supabase
        .from('ledger_entries')
        .stream(primaryKey: ['id'])
        .eq('account', userId)
        .map(_balanceFromRows);
  }

  Future<int> currentBalance() async {
    if (_authenticatedUserId == null) return 0;
    final balance = await _supabase.rpc('wallet_balance');
    return (balance as num?)?.toInt() ?? 0;
  }

  String? get _authenticatedUserId {
    if (!Env.hasSupabase) return null;
    return _supabase.auth.currentUser?.id;
  }

  bool get isServerAvailable => _authenticatedUserId != null;

  int _balanceFromRows(List<Map<String, dynamic>> rows) {
    return rows.fold<int>(
      0,
      (sum, row) {
        final amount = (row['amount_minor'] as num?)?.toInt() ?? 0;
        return sum + (row['direction'] == 'credit' ? amount : -amount);
      },
    );
  }

  Stream<List<WalletEntry>> watchEntries() {
    final userId = _authenticatedUserId;
    if (userId == null) return Stream<List<WalletEntry>>.value(const []);
    return _supabase
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100)
        .map((rows) => rows.map(_fromServerRow).toList(growable: false));
  }

  WalletEntry _fromServerRow(Map<String, dynamic> row) {
    final type = row['type'] as String? ?? 'p2p';
    final meta = row['meta'];
    final metadata = meta is Map ? Map<String, dynamic>.from(meta) : const {};
    final incoming = type == 'topup' ||
        type == 'request' ||
        (type == 'redpacket' && metadata['claim'] == true);
    return WalletEntry(
      id: row['id'] as String,
      type: switch (type) {
        'topup' => WalletTxType.topUp,
        'bill' => WalletTxType.bill,
        'redpacket' => WalletTxType.redPacket,
        'request' => WalletTxType.receive,
        'merchant' => WalletTxType.purchase,
        _ => WalletTxType.transfer,
      },
      direction: incoming
          ? WalletDirection.incoming
          : WalletDirection.outgoing,
      amountMinor: (row['amount_minor'] as num?)?.toInt() ?? 0,
      status: row['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(row['created_at'] as String),
      counterparty: row['provider'] as String?,
      note: metadata['note'] as String?,
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
        return const Result.failure(
            ValidationFailure('Enter your wallet PIN.'));
      }
      try {
        final id = idempotencyKey ?? _uuid.v4();
        final response = await _supabase.functions.invoke(
          'wallet-transfer',
          body: {
            'recipientId': recipient,
            'amountMinor': amountMinor,
            'pin': pin,
            'note': note,
            'idempotencyKey': id,
          },
        );
        final transactionId = (response.data as Map?)?['transactionId'] as String?;
        if (transactionId == null) {
          return const Result.failure(
            ServerFailure('Transfer was not recorded by the server.'),
          );
        }
        final row = await _localRecord(
          type: WalletTxType.transfer,
          amountMinor: amountMinor,
          incoming: false,
          counterparty: recipient,
          note: note,
          idempotencyKey: id,
          transactionId: transactionId,
        );
        return Result.success(row);
      } catch (error) {
        return Result.failure(mapError(error));
      }
    }
    return const Result.failure(
      ValidationFailure('Payments are not enabled in this build.'),
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
    if (_authenticatedUserId == null) {
      return const Result.failure(
        ValidationFailure('Payments are not enabled in this build.'),
      );
    }
    return _requestWalletAction(
      action: 'bill',
      amountMinor: total,
      provider: provider,
      accountRef: accountRef,
      pin: pin,
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
        final transaction = await _supabase
            .from('transactions')
            .select('id')
            .eq('user_id', _authenticatedUserId!)
            .eq('idempotency_key', id)
            .maybeSingle();
        final transactionId = transaction?['id'] as String?;
        if (transactionId == null) {
          return const Result.failure(
            ServerFailure('Red packet was not recorded by the server.'),
          );
        }
        final row = await _localRecord(
          type: WalletTxType.redPacket,
          amountMinor: totalMinor,
          incoming: false,
          counterparty:
              'Red packet · $count ${count == 1 ? 'person' : 'people'}',
          note: note,
          idempotencyKey: id,
          transactionId: transactionId,
        );
        return Result.success(row);
      } catch (error) {
        return Result.failure(mapError(error));
      }
    }
    return const Result.failure(
      ValidationFailure('Payments are not enabled in this build.'),
    );
  }

  Future<Result<WalletTransaction>> topUp({
    required int amountMinor,
    required String provider,
    String? pin,
    String? idempotencyKey,
  }) async {
    if (amountMinor <= 0) {
      return const Result.failure(
        ValidationFailure('Enter an amount greater than zero.'),
      );
    }
    if (_authenticatedUserId == null) {
      return const Result.failure(
        ValidationFailure('Payments are not enabled in this build.'),
      );
    }
    return _requestWalletAction(
      action: 'topup',
      amountMinor: amountMinor,
      provider: provider,
      pin: pin,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Result<WalletTransaction>> purchase({
    required int amountMinor,
    required String provider,
    String? note,
    String? idempotencyKey,
  }) async {
    if (amountMinor <= 0) {
      return const Result.failure(
        ValidationFailure('Enter an amount greater than zero.'),
      );
    }
    if (_authenticatedUserId == null) {
      return const Result.failure(
        ValidationFailure('Payments are not enabled in this build.'),
      );
    }
    return _requestWalletAction(
      action: 'purchase',
      amountMinor: amountMinor,
      provider: provider,
      note: note,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Result<WalletTransaction>> receive({
    required String sender,
    required int amountMinor,
    String? note,
    String? idempotencyKey,
  }) async {
    if (amountMinor < 0) {
      return const Result.failure(
        ValidationFailure('Enter an amount greater than zero.'),
      );
    }
    if (_authenticatedUserId == null) {
      return const Result.failure(
        ValidationFailure('Payment requests are not enabled in this build.'),
      );
    }
    final id = idempotencyKey ?? _uuid.v4();
    try {
      final response = await _supabase.functions.invoke(
        'wallet-action',
        body: {
          'action': 'request',
          'amountMinor': amountMinor,
          'provider': sender,
          'note': note,
          'idempotencyKey': id,
        },
      );
      final transaction = (response.data as Map?)?['transaction'] as Map?;
      final transactionId = transaction?['id'] as String?;
      if (transactionId == null) {
        return const Result.failure(
          ServerFailure('Payment request was not recorded by the server.'),
        );
      }
      final row = await _localRecord(
        type: WalletTxType.receive,
        amountMinor: amountMinor,
        incoming: true,
        counterparty: sender,
        note: note ?? 'Payment request',
        idempotencyKey: id,
        transactionId: transactionId,
        pending: true,
      );
      return Result.success(row);
    } catch (error) {
      return Result.failure(mapError(error));
    }
  }

  Future<Result<WalletTransaction>> _requestWalletAction({
    required String action,
    required int amountMinor,
    required String provider,
    String? accountRef,
    String? note,
    String? pin,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'wallet-action',
        body: {
          'action': action,
          'amountMinor': amountMinor,
          'provider': provider,
          'accountRef': accountRef,
          'note': note,
          'pin': pin,
          'idempotencyKey': idempotencyKey ?? _uuid.v4(),
        },
      );
      final payload = response.data;
      final message = payload is Map ? payload['message'] as String? : null;
      return Result.failure(
        ValidationFailure(
          message ?? 'Payments are not enabled yet. No funds were moved.',
        ),
      );
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
    String? transactionId,
    bool pending = false,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    final existing = await (db.select(db.walletTransactions)
          ..where((t) => t.idempotencyKey.equals(key)))
        .getSingleOrNull();
    if (existing != null) return existing;

    final txnId = transactionId ?? _uuid.v4();
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

}

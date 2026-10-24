import 'package:freezed_annotation/freezed_annotation.dart';

part 'ledger.freezed.dart';

@freezed
class LedgerEntry with _$LedgerEntry {
  const factory LedgerEntry({
    required String id,
    required String txnId,
    required String account,
    required String direction, // debit|credit
    required int amountMinor,
    required String currency,
    required DateTime createdAt,
  }) = _LedgerEntry;
}

@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    String? userId,
    required String type,
    required String status,
    required int amountMinor,
    @Default(0) int feeMinor,
    String? provider,
    String? providerRef,
    String? idempotencyKey,
    Map<String, dynamic>? meta,
    required DateTime createdAt,
  }) = _Transaction;
}

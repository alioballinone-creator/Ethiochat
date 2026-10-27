import 'package:flutter/foundation.dart';

enum WalletDirection { incoming, outgoing }

enum WalletTxType { topUp, transfer, bill, redPacket, receive }

@immutable
class WalletEntry {
  const WalletEntry({
    required this.id,
    required this.type,
    required this.direction,
    required this.amountMinor,
    required this.status,
    required this.createdAt,
    this.counterparty,
    this.note,
  });

  final String id;
  final WalletTxType type;
  final WalletDirection direction;
  final int amountMinor;
  final String status;
  final DateTime createdAt;
  final String? counterparty;
  final String? note;

  bool get incoming => direction == WalletDirection.incoming;
  bool get pending => status == 'pending';
}

@immutable
class PinRequest {
  const PinRequest({
    required this.type,
    required this.amountMinor,
    required this.title,
    this.recipient,
    this.note,
    this.provider,
    this.accountRef,
    this.redPacketCount = 1,
  });

  final WalletTxType type;
  final int amountMinor;
  final String title;
  final String? recipient;
  final String? note;
  final String? provider;
  final String? accountRef;
  final int redPacketCount;
}

@immutable
class WalletReceipt {
  const WalletReceipt({
    required this.title,
    required this.amountMinor,
    required this.type,
    required this.reference,
    required this.createdAt,
    this.counterparty,
    this.note,
  });

  final String title;
  final int amountMinor;
  final WalletTxType type;
  final String reference;
  final DateTime createdAt;
  final String? counterparty;
  final String? note;
}

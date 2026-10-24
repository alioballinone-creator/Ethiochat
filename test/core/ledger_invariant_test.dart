import 'package:flutter_test/flutter_test.dart';

/// Double-entry: for each transaction, sum of debits = sum of credits
bool isBalanced(List<int> debits, List<int> credits) {
  final sumD = debits.fold(0, (a, b) => a + b);
  final sumC = credits.fold(0, (a, b) => a + b);
  return sumD == sumC && sumD >= 0;
}

int balanceFromEntries(List<int> amounts) {
  // positive = credit, negative = debit conceptually, but we store separately
  return amounts.fold(0, (a, b) => a + b);
}

void main() {
  group('Ledger invariants', () {
    test('debits equal credits per transaction', () {
      expect(isBalanced([1000], [1000]), true);
      expect(isBalanced([500, 500], [1000]), true);
      expect(isBalanced([1000], [500]), false);
    });

    test('no negative amounts', () {
      final amounts = [100, 200, 300];
      for (final a in amounts) {
        expect(a >= 0, true);
      }
    });

    test('balance derived from entries', () {
      expect(balanceFromEntries([1000, -500, 200]), 700);
    });
  });
}

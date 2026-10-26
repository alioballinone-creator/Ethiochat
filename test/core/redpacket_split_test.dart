import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

/// Red packet split algorithm: double-mean method, min 1 birr
List<int> splitRedPacket(int totalMinor, int count, Random rng) {
  if (count <= 0) return [];
  if (count == 1) return [totalMinor];
  const minMinor = 100; // 1 birr
  final results = <int>[];
  var remaining = totalMinor;
  var remainingCount = count;
  for (var i = 0; i < count - 1; i++) {
    final max = remaining - minMinor * (remainingCount - 1);
    final amount = minMinor + rng.nextInt(max - minMinor + 1);
    results.add(amount);
    remaining -= amount;
    remainingCount--;
  }
  results.add(remaining);
  return results;
}

void main() {
  group('Red packet split', () {
    test('sum equals total', () {
      final rng = Random(12345);
      for (var trial = 0; trial < 1000; trial++) {
        final total = 10000 + rng.nextInt(90000);
        final count = 2 + rng.nextInt(19);
        final parts = splitRedPacket(total, count, rng);
        expect(parts.fold(0, (a, b) => a + b), total);
      }
    });

    test('each gets at least 1 birr', () {
      final rng = Random(54321);
      for (var trial = 0; trial < 1000; trial++) {
        final total = 5000 + rng.nextInt(50000);
        final count = 2 + rng.nextInt(49);
        final parts = splitRedPacket(total, count, rng);
        for (final p in parts) {
          expect(p >= 100, true);
        }
      }
    });

    test('count matches', () {
      final rng = Random(999);
      final parts = splitRedPacket(10000, 10, rng);
      expect(parts.length, 10);
    });
  });
}

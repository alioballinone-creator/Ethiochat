import 'package:ethiochat/core/config/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Wallet feature flag', () {
    test('wallet disabled by default', () {
      expect(FeatureFlags.wallet, isFalse);
    });

    test('payments requires wallet', () {
      expect(FeatureFlags.payments, equals(FeatureFlags.wallet));
    });
  });
}

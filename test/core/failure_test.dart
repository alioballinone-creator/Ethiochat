import 'package:ethiochat/core/errors/failure.dart';
import 'package:ethiochat/core/errors/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Result folds success', () {
    const r = Result.success(42);
    final v = r.fold((f) => -1, (x) => x);
    expect(v, 42);
  });

  test('Result folds failure', () {
    const r = Result<int>.failure(NetworkFailure('offline'));
    final v = r.fold((f) => f.message, (x) => '$x');
    expect(v, 'offline');
  });

  test('mapError maps network strings', () {
    final f = mapError(Exception('SocketException: failed host lookup'));
    expect(f, isA<NetworkFailure>());
  });

  test('mapError preserves Failure', () {
    const nf = TimeoutFailure();
    expect(mapError(nf), same(nf));
  });
}

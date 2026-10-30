import 'dart:async';

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

  test('maps timeouts to a friendly localized failure', () {
    final failure = mapError(TimeoutException('private backend details'));

    expect(failure, isA<TimeoutFailure>());
    expect(failure.message, isNot(contains('private backend details')));
    expect(failure.messageFor('am'), contains('እንደገና ይሞክሩ'));
  });

  test('maps server responses without exposing backend messages or codes', () {
    final failure = mapError(
      StateError('HTTP 500: sensitive database detail'),
    );

    expect(failure, isA<ServerFailure>());
    expect(failure.message, isNot(contains('500')));
    expect(failure.message, isNot(contains('sensitive database detail')));
  });

  test('typed failures do not expose backend messages when rendered directly',
      () {
    const failure = ServerFailure(
      'HTTP 500: sensitive database detail',
      '500',
      'raw backend response',
    );

    expect(failure.message, isNot(contains('500')));
    expect(failure.message, isNot(contains('sensitive database detail')));
    expect(failure.messageFor('en'), isNot(contains('raw backend response')));
  });
}

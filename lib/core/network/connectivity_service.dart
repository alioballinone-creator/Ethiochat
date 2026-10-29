import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../logging/app_logger.dart';

enum NetworkStatus { online, weak, offline }

/// Combines connectivity_plus with reachability. Exposes status for banners.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final _controller = StreamController<NetworkStatus>.broadcast();
  NetworkStatus _status = NetworkStatus.online;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _started = false;
  bool _disposed = false;

  NetworkStatus get status => _status;
  Stream<NetworkStatus> get stream => _controller.stream;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    try {
      final initial = await _connectivity.checkConnectivity();
      if (_disposed) return;
      _update(initial);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Initial connectivity check failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_disposed) _update(const [ConnectivityResult.none]);
    }
    if (_disposed) return;
    _subscription = _connectivity.onConnectivityChanged.listen(
      _update,
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.warn(
          'Connectivity stream failed',
          error: error,
          stackTrace: stackTrace,
        );
        if (!_disposed) _update(const [ConnectivityResult.none]);
      },
    );
  }

  void _update(List<ConnectivityResult> results) {
    if (_disposed) return;
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    if (!hasNetwork) {
      _status = NetworkStatus.offline;
    } else {
      // Reachability ping would go here; default to online for Phase 1
      _status = NetworkStatus.online;
    }
    _controller.add(_status);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _controller.close();
  }
}

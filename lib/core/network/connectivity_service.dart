import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkStatus { online, weak, offline }

/// Combines connectivity_plus with reachability. Exposes status for banners.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final _controller = StreamController<NetworkStatus>.broadcast();
  NetworkStatus _status = NetworkStatus.online;

  NetworkStatus get status => _status;
  Stream<NetworkStatus> get stream => _controller.stream;

  Future<void> start() async {
    final initial = await _connectivity.checkConnectivity();
    _update(initial);
    _connectivity.onConnectivityChanged.listen(_update);
  }

  void _update(List<ConnectivityResult> results) {
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
    _controller.close();
  }
}

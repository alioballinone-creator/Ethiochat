/// The real media lifecycle of a call. UI text is derived from this state and
/// never from a local timer or optimistic button press.
enum CallPhase {
  idle,
  requesting,
  ringing,
  connecting,
  connected,
  reconnecting,
  ended,
  failed,
}

class CallLifecycle {
  CallPhase _phase = CallPhase.idle;
  String? _error;

  CallPhase get phase => _phase;
  String? get error => _error;
  bool get isActive =>
      _phase != CallPhase.idle &&
      _phase != CallPhase.ended &&
      _phase != CallPhase.failed;
  bool get isConnected => _phase == CallPhase.connected;

  void beginOutgoing() {
    _error = null;
    _phase = CallPhase.requesting;
  }

  void beginIncoming() {
    _error = null;
    _phase = CallPhase.ringing;
  }

  void markRinging() {
    _error = null;
    _phase = CallPhase.ringing;
  }

  void markConnecting() {
    _error = null;
    _phase = CallPhase.connecting;
  }

  void markConnected() {
    _error = null;
    _phase = CallPhase.connected;
  }

  void markReconnecting() {
    _phase = CallPhase.reconnecting;
  }

  void markEnded() {
    _phase = CallPhase.ended;
  }

  void markFailed(String message) {
    _error = message;
    _phase = CallPhase.failed;
  }
}

class CallJoinInfo {
  const CallJoinInfo({
    required this.url,
    required this.token,
    required this.roomName,
    required this.callId,
    required this.identity,
  });

  final String url;
  final String token;
  final String roomName;
  final String callId;
  final String identity;
}

class CallException implements Exception {
  const CallException(this.message);

  final String message;

  @override
  String toString() => message;
}

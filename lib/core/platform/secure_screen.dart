import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Blocks screenshots and screen recording for wallet and PIN surfaces.
///
/// Uses a reference count so leaving an inner PIN screen does not re-enable
/// capture while the wallet underneath is still visible.
abstract final class SecureScreen {
  static const _channel = MethodChannel('ethiochat/secure_screen');
  static int _depth = 0;

  static Future<void> enable() async {
    _depth++;
    if (_depth > 1) return;
    await _set(true);
  }

  static Future<void> disable() async {
    if (_depth == 0) return;
    _depth--;
    if (_depth > 0) return;
    await _set(false);
  }

  static Future<void> _set(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'enabled': enabled});
    } on MissingPluginException {
      // Widget tests and unsupported embeddings have no native channel.
    } on PlatformException {
      // Screenshot protection is best-effort on OEM builds.
    }
  }
}

/// Wraps a wallet or PIN surface and enables native screenshot protection for
/// as long as it is mounted.
class SecureScreenScope extends StatefulWidget {
  const SecureScreenScope({super.key, required this.child});

  final Widget child;

  @override
  State<SecureScreenScope> createState() => _SecureScreenScopeState();
}

class _SecureScreenScopeState extends State<SecureScreenScope> {
  @override
  void initState() {
    super.initState();
    SecureScreen.enable();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

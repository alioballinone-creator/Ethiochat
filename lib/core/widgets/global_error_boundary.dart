import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/failure.dart';
import 'error_view.dart';

class GlobalErrorBoundary extends ConsumerStatefulWidget {
  const GlobalErrorBoundary({
    super.key,
    required this.child,
    this.onError,
  });

  final Widget child;
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  ConsumerState<GlobalErrorBoundary> createState() =>
      _GlobalErrorBoundaryState();
}

class _GlobalErrorBoundaryState extends ConsumerState<GlobalErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    FlutterError.onError = (details) {
      if (_error != null) return;
      FlutterError.presentError(details);
      if (mounted) {
        setState(() {
          _error = details.exception;
          _stackTrace = details.stack;
        });
      }
      widget.onError?.call(details.exception, details.stack ?? StackTrace.current);
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final failure = mapError(_error!, _stackTrace);
      return Material(
        child: ErrorView(
          failure: failure,
          onRetry: () {
            setState(() {
              _error = null;
              _stackTrace = null;
            });
          },
        ),
      );
    }
    return widget.child;
  }
}

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logging/app_logger.dart';

class GlobalErrorBoundary extends StatefulWidget {
  const GlobalErrorBoundary({super.key, required this.child});

  final Widget child;

  static _GlobalErrorBoundaryState? _state;

  static bool capture() {
    return _state?._capture() ?? false;
  }

  @override
  State<GlobalErrorBoundary> createState() => _GlobalErrorBoundaryState();
}

class _GlobalErrorBoundaryState extends State<GlobalErrorBoundary> {
  bool _hasError = false;
  int _retry = 0;

  @override
  void initState() {
    super.initState();
    GlobalErrorBoundary._state = this;
  }

  @override
  void dispose() {
    if (identical(GlobalErrorBoundary._state, this)) {
      GlobalErrorBoundary._state = null;
    }
    super.dispose();
  }

  bool _capture() {
    if (!mounted) return false;
    if (_hasError) return true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasError) setState(() => _hasError = true);
    });
    return true;
  }

  void _retryApp() {
    setState(() {
      _retry++;
      _hasError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasError) {
      return KeyedSubtree(key: ValueKey(_retry), child: widget.child);
    }

    final isAmharic = ui.PlatformDispatcher.instance.locale.languageCode == 'am';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 52),
                  const SizedBox(height: 16),
                  Text(
                    isAmharic ? 'ችግር ተፈጥሯል' : 'Something went wrong',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAmharic
                        ? 'መረጃዎ አልጠፋም። እባክዎ እንደገና ይሞክሩ።'
                        : 'Your data is safe. Please try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _retryApp,
                    child: Text(isAmharic ? 'እንደገና ይሞክሩ' : 'Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void installGlobalErrorBoundary() {
  final previousFlutterError = FlutterError.onError;
  final previousErrorWidgetBuilder = ErrorWidget.builder;
  final previousPlatformError = ui.PlatformDispatcher.instance.onError;
  FlutterError.onError = (details) {
    if (GlobalErrorBoundary.capture()) {
      AppLogger.error('Flutter framework error');
    } else {
      previousFlutterError?.call(details);
    }
  };
  ErrorWidget.builder = (details) {
    if (GlobalErrorBoundary.capture()) return const SizedBox.shrink();
    return previousErrorWidgetBuilder(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stackTrace) {
    if (GlobalErrorBoundary.capture()) {
      AppLogger.error('Unhandled asynchronous application error');
      return true;
    }
    return previousPlatformError?.call(error, stackTrace) ?? false;
  };
}

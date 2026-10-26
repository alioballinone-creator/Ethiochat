import 'package:flutter/material.dart';

class FadePageRoute<T> extends PageRouteBuilder<T> {
  FadePageRoute({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 250),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );

  final Widget child;
}

class SlidePageRoute<T> extends PageRouteBuilder<T> {
  SlidePageRoute({required this.child, this.direction = AxisDirection.left})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final begin = switch (direction) {
              AxisDirection.up => const Offset(0, 1),
              AxisDirection.down => const Offset(0, -1),
              AxisDirection.right => const Offset(-1, 0),
              AxisDirection.left => const Offset(1, 0),
            };
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;
            final tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );

  final Widget child;
  final AxisDirection direction;
}

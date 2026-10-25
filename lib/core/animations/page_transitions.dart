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
            Offset begin;
            switch (direction) {
              case AxisDirection.up:
                begin = const Offset(0, 1);
                break;
              case AxisDirection.down:
                begin = const Offset(0, -1);
                break;
              case AxisDirection.right:
                begin = const Offset(-1, 0);
                break;
              case AxisDirection.left:
              default:
                begin = const Offset(1, 0);
                break;
            }
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );

  final Widget child;
  final AxisDirection direction;
}

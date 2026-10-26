import 'package:flutter/material.dart';

/// 4-pt grid. Never use raw numbers in widgets; use these.
abstract final class Sp {
  static const double x1 = 4, x2 = 8, x3 = 12, x4 = 16, x5 = 20, x6 = 24, x8 = 32, x10 = 40;
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: 20);
}

abstract final class Rad {
  static const double sm = 10, md = 14, lg = 18, xl = 24, pill = 999;
  static final r10 = BorderRadius.circular(sm);
  static final r14 = BorderRadius.circular(md);
  static final r18 = BorderRadius.circular(lg);
  static final r24 = BorderRadius.circular(xl);
}

abstract final class Dur {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);
  static const curve = Curves.easeOutCubic;
}

/// Minimum touch target (dp). The master prompt requires 48; primary actions use 54.
const double kTouch = 48;

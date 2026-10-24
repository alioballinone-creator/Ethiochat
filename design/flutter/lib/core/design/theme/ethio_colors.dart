import 'package:flutter/material.dart';

/// The single source of truth for EthioChat brand colours.
///
/// Gold is an accent, never a background for body text. Text on gold must be
/// [EthioColors.black] to satisfy WCAG AA.
abstract final class EthioColors {
  static const goldDeep = Color(0xFFB8860B);
  static const gold = Color(0xFFD4AF37);
  static const goldLight = Color(0xFFF4D77A);
  static const cream = Color(0xFFFFF8E7);
  static const creamDark = Color(0xFFF3E9CC);
  static const black = Color(0xFF0B0B0B);
  static const blackSoft = Color(0xFF1A1A1A);
  static const danger = Color(0xFFC0392B);

  /// "Shiny gold" gradient, reserved for the primary button, logo, wallet card
  /// and the selected tab indicator.
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldDeep, gold, goldLight, gold],
  );

  static const goldGradientSubtle = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldDeep, gold],
  );
}

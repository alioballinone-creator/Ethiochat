import 'package:flutter/material.dart';

/// Brand palette. Names match section 1 of the EthioChat master prompt.
abstract final class EthioColors {
  static const goldDeep = Color(0xFFB8860B);
  static const gold = Color(0xFFD4AF37);
  static const goldLight = Color(0xFFF4D77A);
  static const cream = Color(0xFFFFF8E7);
  static const creamDark = Color(0xFFF3E9CC);
  static const black = Color(0xFF0B0B0B);
  static const blackSoft = Color(0xFF1A1A1A);
  static const danger = Color(0xFFC0392B);
  static const success = Color(0xFF2E7D4F);

  /// Shiny gold. Use ONLY on: primary button, wallet card, selected nav pill,
  /// logo, voice/send buttons, unread badges and dark-mode sent bubbles.
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, goldDeep],
    stops: [0.0, 0.55, 1.0],
  );

  /// Warm, muted avatar tones (never bright primaries).
  static const avatarTones = <Color>[
    Color(0xFF8C5A2B),
    Color(0xFFB8860B),
    Color(0xFF4A4034),
    Color(0xFFA5472F),
    Color(0xFF6B7A3A),
    Color(0xFF7A5C8F),
    Color(0xFF2F6B6B),
    Color(0xFFC98B2B),
  ];
}

/// Semantic colours that differ per theme. Read with `EthioPalette.of(context)`.
@immutable
class EthioPalette extends ThemeExtension<EthioPalette> {
  const EthioPalette({
    required this.surface2,
    required this.line,
    required this.textSecondary,
    required this.textTertiary,
    required this.chip,
    required this.ring,
    required this.wallpaper,
    required this.navBackground,
    required this.bubbleReceived,
    required this.bubbleSent,
    required this.bubbleSentText,
    required this.tickSent,
    required this.tickRead,
  });

  final Color surface2, line, textSecondary, textTertiary, chip, ring;
  final Color wallpaper, navBackground, bubbleReceived, bubbleSentText;
  final Color tickSent, tickRead;
  final Gradient bubbleSent;

  static const _blackFill =
      LinearGradient(colors: [EthioColors.black, EthioColors.black]);

  /// Light: sent bubbles are black with cream text; gold ticks pop on black.
  static const light = EthioPalette(
    surface2: Color(0xFFF6EDD2),
    line: Color(0xFFEADFC0),
    textSecondary: Color(0xFF6E6550),
    textTertiary: Color(0xFFA09676),
    chip: EthioColors.creamDark,
    ring: Color(0x59B8860B),
    wallpaper: Color(0xFFFBF1D6),
    navBackground: Color(0xFFFFFDF6),
    bubbleReceived: Color(0xFFFFFFFF),
    bubbleSent: _blackFill,
    bubbleSentText: EthioColors.cream,
    tickSent: EthioColors.gold,
    tickRead: EthioColors.gold,
  );

  /// Dark: sent bubbles are shiny gold with black text; ticks go dark-brown.
  static const dark = EthioPalette(
    surface2: Color(0xFF201E1A),
    line: Color(0xFF2A2722),
    textSecondary: Color(0xFFA89F88),
    textTertiary: Color(0xFF6F6858),
    chip: Color(0xFF241F14),
    ring: Color(0x59D4AF37),
    wallpaper: Color(0xFF0E0D0B),
    navBackground: Color(0xFF121110),
    bubbleReceived: Color(0xFF1F1D19),
    bubbleSent: EthioColors.goldGradient,
    bubbleSentText: EthioColors.black,
    tickSent: Color(0xFF4A3A06),
    tickRead: Color(0xFF0B0B0B),
  );

  static EthioPalette of(BuildContext context) =>
      Theme.of(context).extension<EthioPalette>()!;

  @override
  EthioPalette copyWith() => this;

  @override
  EthioPalette lerp(ThemeExtension<EthioPalette>? other, double t) {
    if (other is! EthioPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return EthioPalette(
      surface2: l(surface2, other.surface2),
      line: l(line, other.line),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      chip: l(chip, other.chip),
      ring: l(ring, other.ring),
      wallpaper: l(wallpaper, other.wallpaper),
      navBackground: l(navBackground, other.navBackground),
      bubbleReceived: l(bubbleReceived, other.bubbleReceived),
      bubbleSent: t < 0.5 ? bubbleSent : other.bubbleSent,
      bubbleSentText: l(bubbleSentText, other.bubbleSentText),
      tickSent: l(tickSent, other.tickSent),
      tickRead: l(tickRead, other.tickRead),
    );
  }
}

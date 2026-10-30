import 'package:flutter/material.dart';
import 'ethio_colors.dart';
import 'ethio_spacing.dart';

/// Poppins for all Latin UI text (see DESIGN.md); Noto Sans Ethiopic for Ge'ez.
const _fam = 'Poppins';
const _fallback = ['NotoSansEthiopic'];

TextStyle _s(double size, FontWeight w,
        {double h = 1.35, double ls = 0, Color? c}) =>
    TextStyle(
      fontFamily: _fam,
      fontFamilyFallback: _fallback,
      fontSize: size,
      fontWeight: w,
      height: h,
      letterSpacing: ls,
      color: c,
    );

TextTheme _textTheme(Color on) => TextTheme(
      headlineMedium: _s(28, FontWeight.w700, ls: -0.3, c: on), // screen titles
      titleLarge: _s(22, FontWeight.w700, c: on), // sub-screen titles
      titleMedium:
          _s(16, FontWeight.w600, c: on), // list titles, section titles
      bodyLarge: _s(15.5, FontWeight.w400, c: on),
      bodyMedium: _s(15, FontWeight.w400,
          c: on), // default body (min 16sp on small phones via textScaler)
      bodySmall: _s(13.5, FontWeight.w400, c: on),
      labelLarge: _s(16, FontWeight.w600, c: on), // buttons
      labelMedium: _s(13, FontWeight.w500, c: on), // chips
      labelSmall: _s(12, FontWeight.w500, c: on), // captions, time
    );

ThemeData buildEthioTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final pal = dark ? EthioPalette.dark : EthioPalette.light;
  final bg = dark ? EthioColors.black : EthioColors.cream;
  final surface = dark ? const Color(0xFF161513) : const Color(0xFFFFFDF6);
  final on = dark ? EthioColors.cream : EthioColors.black;

  final scheme = ColorScheme(
    brightness: b,
    primary: EthioColors.gold,
    onPrimary: EthioColors.black,
    secondary: EthioColors.goldDeep,
    onSecondary: EthioColors.cream,
    surface: surface,
    onSurface: on,
    error: EthioColors.danger,
    onError: Colors.white,
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: Rad.r14, borderSide: BorderSide(color: c, width: w));

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    fontFamily: _fam,
    fontFamilyFallback: _fallback,
    textTheme: _textTheme(on),
    extensions: [pal],
    splashFactory: InkRipple.splashFactory,
    dividerTheme: DividerThemeData(color: pal.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: on,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: _s(22, FontWeight.w700, c: on),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: _s(15, FontWeight.w400, c: pal.textTertiary),
      border: border(pal.line),
      enabledBorder: border(pal.line),
      focusedBorder: border(EthioColors.gold, 1.5),
      errorBorder: border(EthioColors.danger, 1.5),
      focusedErrorBorder: border(EthioColors.danger, 1.5),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: pal.chip,
      selectedColor: EthioColors.gold,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: _s(13, FontWeight.w500, c: on),
      secondaryLabelStyle: _s(13, FontWeight.w600, c: EthioColors.black),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: on,
      contentTextStyle: _s(14, FontWeight.w400, c: bg),
      actionTextColor: EthioColors.gold,
      shape: RoundedRectangleBorder(borderRadius: Rad.r14),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: Rad.r24),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: EthioColors.gold),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? EthioColors.black
              : pal.textTertiary),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? EthioColors.gold : pal.line),
    ),
  );
}

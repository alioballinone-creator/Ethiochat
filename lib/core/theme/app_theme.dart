import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_spacing.dart';
import 'ethio_colors.dart';

/// Builds the light or dark EthioChat theme.
///
/// Gold-on-cream text is forbidden; when gold is a surface the foreground is
/// always black. All text styles use Inter with a Noto Sans Ethiopic fallback
/// so Ge'ez and Latin can be mixed freely.
ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: EthioColors.gold,
    onPrimary: EthioColors.black,
    primaryContainer: isDark ? EthioColors.blackSoft : EthioColors.creamDark,
    onPrimaryContainer: isDark ? EthioColors.cream : EthioColors.black,
    secondary: EthioColors.goldDeep,
    onSecondary: EthioColors.cream,
    secondaryContainer: isDark ? EthioColors.blackSoft : EthioColors.creamDark,
    onSecondaryContainer: isDark ? EthioColors.cream : EthioColors.black,
    surface: isDark ? EthioColors.blackSoft : EthioColors.cream,
    onSurface: isDark ? EthioColors.cream : EthioColors.black,
    surfaceContainerHighest:
        isDark ? const Color(0xFF252525) : EthioColors.creamDark,
    onSurfaceVariant:
        isDark ? const Color(0xFFCFC6AF) : const Color(0xFF4A463C),
    outline: isDark ? const Color(0xFF5C574A) : const Color(0xFFBDB49E),
    outlineVariant: isDark ? const Color(0xFF35322B) : EthioColors.creamDark,
    error: EthioColors.danger,
    onError: Colors.white,
    inverseSurface: isDark ? EthioColors.cream : EthioColors.black,
    onInverseSurface: isDark ? EthioColors.black : EthioColors.cream,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? EthioColors.black : EthioColors.cream,
    fontFamily: 'Inter',
    fontFamilyFallback: const ['NotoSansEthiopic'],
    visualDensity: VisualDensity.standard,
  );

  final textTheme = base.textTheme.copyWith(
    displaySmall: base.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 24,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 20,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 17,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.4),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.4),
    bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 13, height: 1.35),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 16,
    ),
    labelSmall: base.textTheme.labelSmall?.copyWith(fontSize: 12),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? EthioColors.black : EthioColors.cream,
      foregroundColor: isDark ? EthioColors.cream : EthioColors.black,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: isDark ? EthioColors.cream : EthioColors.black,
      ),
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: EthioColors.gold,
        foregroundColor: EthioColors.black,
        disabledBackgroundColor:
            isDark ? EthioColors.blackSoft : EthioColors.creamDark,
        disabledForegroundColor:
            isDark ? const Color(0xFF777266) : const Color(0xFF8D8574),
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? EthioColors.cream : EthioColors.black,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(
          color: isDark ? const Color(0xFF4F4B40) : EthioColors.goldDeep,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: isDark ? EthioColors.goldLight : EthioColors.goldDeep,
        minimumSize: const Size(48, AppSpacing.minTouchTarget),
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? EthioColors.blackSoft : Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      hintStyle: textTheme.bodyLarge?.copyWith(
        color: isDark ? const Color(0xFF9B9588) : const Color(0xFF807A6C),
      ),
      labelStyle: textTheme.bodyMedium,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3832) : EthioColors.creamDark,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3832) : EthioColors.creamDark,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        borderSide: const BorderSide(color: EthioColors.gold, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        borderSide: const BorderSide(color: EthioColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        borderSide: const BorderSide(color: EthioColors.danger, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      color: isDark ? EthioColors.blackSoft : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        side: BorderSide(
          color: isDark ? const Color(0xFF2B2924) : EthioColors.creamDark,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? const Color(0xFF2B2924) : EthioColors.creamDark,
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? EthioColors.black : EthioColors.cream,
      indicatorColor: EthioColors.gold.withValues(alpha: 0.22),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelSmall?.copyWith(
          color: selected
              ? (isDark ? EthioColors.goldLight : EthioColors.goldDeep)
              : scheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected
              ? EthioColors.goldDeep
              : (isDark ? const Color(0xFFB8B1A2) : const Color(0xFF6B6558)),
        );
      }),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isDark ? EthioColors.blackSoft : EthioColors.cream,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? EthioColors.cream : EthioColors.black,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: isDark ? EthioColors.black : EthioColors.cream,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isDark ? EthioColors.blackSoft : EthioColors.creamDark,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      labelStyle: textTheme.bodySmall,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: EthioColors.goldDeep,
    ),
    iconTheme: IconThemeData(
      color: isDark ? EthioColors.cream : EthioColors.black,
      size: 22,
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: AppSpacing.sm,
      iconColor: isDark ? EthioColors.cream : EthioColors.black,
    ),
  );
}

/// Both themes are created once and shared, avoiding rebuild cost on toggle.
final ThemeData lightTheme = buildTheme(Brightness.light);
final ThemeData darkTheme = buildTheme(Brightness.dark);

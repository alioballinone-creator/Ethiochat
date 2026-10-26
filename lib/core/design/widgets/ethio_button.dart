import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ethio_colors.dart';
import '../ethio_spacing.dart';

enum EthioButtonKind { primary, secondary, tonal, danger, text }

enum EthioButtonSize { large, small }

/// One button for the whole app. Primary = shiny gold, one per screen.
class EthioButton extends StatelessWidget {
  const EthioButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = EthioButtonKind.primary,
    this.size = EthioButtonSize.large,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final EthioButtonKind kind;
  final EthioButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool expand;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final h = size == EthioButtonSize.large ? 54.0 : 46.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color fg;
    BoxDecoration deco;
    switch (kind) {
      case EthioButtonKind.primary:
        fg = EthioColors.black;
        deco = BoxDecoration(
          gradient: EthioColors.goldGradient,
          borderRadius: Rad.r14,
          boxShadow: [
            BoxShadow(
                color:
                    EthioColors.goldDeep.withValues(alpha: isDark ? .35 : .45),
                blurRadius: 18,
                offset: const Offset(0, 8),
                spreadRadius: -8)
          ],
        );
      case EthioButtonKind.secondary:
        fg = Theme.of(context).colorScheme.onSurface;
        deco = BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: Rad.r14,
            border: Border.all(color: EthioColors.gold, width: 1.5));
      case EthioButtonKind.tonal:
        fg = Theme.of(context).colorScheme.onSurface;
        deco = BoxDecoration(color: pal.chip, borderRadius: Rad.r14);
      case EthioButtonKind.danger:
        fg = Colors.white;
        deco = BoxDecoration(color: EthioColors.danger, borderRadius: Rad.r14);
      case EthioButtonKind.text:
        fg = isDark ? EthioColors.gold : EthioColors.goldDeep;
        deco = const BoxDecoration();
    }

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 8)
          ],
          Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      color: fg,
                      fontSize: size == EthioButtonSize.large ? 16 : 14))),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      child: AnimatedOpacity(
        duration: Dur.fast,
        opacity: onPressed == null ? .45 : 1,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: deco,
            height: h,
            child: InkWell(
              borderRadius: Rad.r14,
              onTap: _enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      onPressed!();
                    }
                  : null,
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: content),
            ),
          ),
        ),
      ),
    );
  }
}

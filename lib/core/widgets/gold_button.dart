import 'package:flutter/material.dart';
import 'package:ethiochat/core/theme/ethio_colors.dart';

/// Primary button using the "shiny gold" gradient.
/// Text must always be black (gold-on-cream text is forbidden).
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.loading = false,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? EthioColors.goldGradient : null,
        color: enabled
            ? null
            : Theme.of(context).disabledColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: EthioColors.black),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: EthioColors.black),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: EthioColors.black,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

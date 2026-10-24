import 'package:flutter/material.dart';
import '../theme/ethio_colors.dart';

class EthioButton extends StatelessWidget {
  const EthioButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? EthioColors.goldGradient : null,
        color: enabled ? null : Theme.of(context).disabledColor.withValues(alpha: 0.3),
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: EthioColors.black),
                  )
                : Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: EthioColors.black,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
          ),
        ),
      ),
    );
  }
}

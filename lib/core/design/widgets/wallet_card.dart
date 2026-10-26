import 'package:flutter/material.dart';
import '../ethio_colors.dart';
import '../ethio_spacing.dart';

/// Gold balance card. Amount is passed in minor units (cents) to avoid float errors.
class WalletCard extends StatelessWidget {
  const WalletCard(
      {super.key,
      required this.balanceMinor,
      required this.ethioId,
      this.verified = false,
      this.hidden = false,
      this.onToggleHidden});

  final int balanceMinor;
  final String ethioId;
  final bool verified, hidden;
  final VoidCallback? onToggleHidden;

  String get _amount {
    final whole = (balanceMinor ~/ 100)
        .toString()
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    final cents = (balanceMinor % 100).toString().padLeft(2, '0');
    return 'ETB $whole.$cents';
  }

  @override
  Widget build(BuildContext context) {
    const ink = EthioColors.black;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: Rad.r24,
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7E09A), EthioColors.gold, Color(0xFFA9780B)],
            stops: [0, .4, 1]),
        boxShadow: [
          BoxShadow(
              color: EthioColors.goldDeep.withValues(alpha: .55),
              blurRadius: 30,
              offset: const Offset(0, 18),
              spreadRadius: -16)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Available balance',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium!
                    .copyWith(color: ink.withValues(alpha: .8))),
          ),
          IconButton(
            onPressed: onToggleHidden,
            visualDensity: VisualDensity.compact,
            icon: Icon(
                hidden
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: ink,
                size: 20),
            tooltip: hidden ? 'Show balance' : 'Hide balance',
          ),
        ]),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(hidden ? 'ETB ••••••' : _amount,
              maxLines: 1,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: ink,
                  letterSpacing: -.5,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(
            child: Text('Ethio ID · $ethioId',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium!
                    .copyWith(color: ink)),
          ),
          if (verified) ...[
            const Icon(Icons.verified_user_outlined, size: 16, color: ink),
            const SizedBox(width: 5),
            Text('Verified',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium!
                    .copyWith(color: ink)),
          ],
        ]),
      ]),
    );
  }
}

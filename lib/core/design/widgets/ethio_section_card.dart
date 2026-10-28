import 'package:flutter/material.dart';

import '../ethio_colors.dart';
import '../ethio_spacing.dart';

/// Grouped white/black card used by settings, profile and wallet sub-pages.
class EthioSectionCard extends StatelessWidget {
  const EthioSectionCard({
    super.key,
    required this.children,
    this.padding,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: Rad.r18,
        border: Border.all(color: pal.line),
      ),
      clipBehavior: Clip.antiAlias,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class EthioSectionLabel extends StatelessWidget {
  const EthioSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.x1, Sp.x4, Sp.x1, Sp.x2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: pal.textTertiary,
                    letterSpacing: 0.8,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EthioIconTile extends StatelessWidget {
  const EthioIconTile({
    super.key,
    required this.icon,
    this.size = 44,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? pal.chip,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: size * 0.5, color: foreground),
    );
  }
}

class EthioNavRow extends StatelessWidget {
  const EthioNavRow({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.subtitle,
    this.trailing,
    this.last = false,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool last;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        ListTile(
          enabled: enabled,
          onTap: enabled ? onTap : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Sp.x4,
            vertical: Sp.x1,
          ),
          leading: EthioIconTile(icon: icon),
          title: Text(title, style: text.titleMedium),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: text.labelSmall?.copyWith(color: pal.textSecondary),
                ),
          trailing: trailing ??
              Icon(
                Icons.chevron_right_rounded,
                color: pal.textTertiary,
              ),
        ),
        if (!last)
          Divider(
            height: 1,
            indent: Sp.x4 + 44 + Sp.x3,
            endIndent: Sp.x4,
            color: pal.line,
          ),
      ],
    );
  }
}

class EthioSwitchRow extends StatelessWidget {
  const EthioSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        SwitchListTile.adaptive(
          value: value,
          onChanged: onChanged,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Sp.x4,
            vertical: Sp.x1,
          ),
          secondary: EthioIconTile(icon: icon),
          title: Text(title, style: text.titleMedium),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: text.labelSmall?.copyWith(color: pal.textSecondary),
                ),
          activeTrackColor: EthioColors.gold,
        ),
        if (!last)
          Divider(
            height: 1,
            indent: Sp.x4 + 44 + Sp.x3,
            endIndent: Sp.x4,
            color: pal.line,
          ),
      ],
    );
  }
}

class EthioEmptyState extends StatelessWidget {
  const EthioEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: Sp.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: pal.chip,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: pal.textSecondary),
            ),
            const SizedBox(height: Sp.x4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Sp.x1),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: pal.textSecondary),
            ),
            if (action != null) ...[
              const SizedBox(height: Sp.x4),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 44 dp coloured tile used by mini programs.
class EthioMiniAppTile extends StatelessWidget {
  const EthioMiniAppTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: Rad.r14,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color ?? pal.chip,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pal.line),
            ),
            child: Icon(icon, size: 26),
          ),
          const SizedBox(height: Sp.x2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../design/ethio_colors.dart';

class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.height,
    this.width,
    this.borderRadius = 8,
  });

  final double? height;
  final double? width;
  final double borderRadius;

  @Override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: EthioColors.slate.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class ChatListItemSkeleton extends StatelessWidget {
  const ChatListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const SkeletonBox(height: 48, width: 48, borderRadius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: SkeletonBox(height: 14, width: 120)),
                    const SizedBox(width: 8),
                    SkeletonBox(height: 10, width: 40),
                  ],
                ),
                const SizedBox(height: 8),
                SkeletonBox(height: 12, width: double.infinity),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({super.key, this.itemCount = 8});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, __) => const ChatListItemSkeleton(),
      ),
    );
  }
}

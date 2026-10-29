import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../ethio_colors.dart';
import '../ethio_spacing.dart';

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
    this.circle = false,
  });

  final double width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final palette = EthioPalette.of(context);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shape = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: palette.line,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
    if (reduceMotion) return shape;
    return Shimmer.fromColors(
      baseColor: palette.line,
      highlightColor: palette.surface2,
      period: const Duration(milliseconds: 1400),
      child: shape,
    );
  }
}

class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({super.key, this.count = 7});

  final int count;

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.only(top: Sp.x2),
        itemCount: count,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: Row(
            children: [
              SkeletonBox(width: 54, height: 54, circle: true),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 148, height: 14),
                    SizedBox(height: 8),
                    SkeletonBox(width: 132, height: 12),
                  ],
                ),
              ),
              SizedBox(width: Sp.x4),
              SkeletonBox(width: 34, height: 11),
            ],
          ),
        ),
      );
}

class ContactListSkeleton extends StatelessWidget {
  const ContactListSkeleton({super.key, this.count = 7});

  final int count;

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: Sp.screen.copyWith(top: Sp.x3),
        itemCount: count,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.symmetric(vertical: Sp.x2),
          child: Row(
            children: [
              SkeletonBox(width: 48, height: 48, circle: true),
              SizedBox(width: Sp.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 140, height: 14),
                    SizedBox(height: 8),
                    SkeletonBox(width: 96, height: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class MessageListSkeleton extends StatelessWidget {
  const MessageListSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: Sp.screen,
        itemCount: count,
        itemBuilder: (context, index) {
          final sent = index.isOdd;
          return Align(
            alignment: sent ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Sp.x1),
              child: SkeletonBox(
                width: sent ? 190 : 220,
                height: 48 + (index % 3) * 12,
                radius: 16,
              ),
            ),
          );
        },
      );
}

class TransactionListSkeleton extends StatelessWidget {
  const TransactionListSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: Sp.screen.copyWith(top: Sp.x3),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: Sp.x3),
        itemBuilder: (context, index) => const Row(
          children: [
            SkeletonBox(width: 40, height: 40, circle: true),
            SizedBox(width: Sp.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 128, height: 14),
                  SizedBox(height: Sp.x1),
                  SkeletonBox(width: 172, height: 11),
                ],
              ),
            ),
            SizedBox(width: Sp.x2),
            SkeletonBox(width: 58, height: 14),
          ],
        ),
      );
}

class ProfileHeaderSkeleton extends StatelessWidget {
  const ProfileHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          SkeletonBox(width: 64, height: 64, circle: true),
          SizedBox(width: Sp.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 142, height: 17),
                SizedBox(height: Sp.x2),
                SkeletonBox(width: 110, height: 12),
              ],
            ),
          ),
        ],
      );
}

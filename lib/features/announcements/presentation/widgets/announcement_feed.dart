import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/design.dart';
import '../../application/announcements_provider.dart';

class AnnouncementFeed extends ConsumerWidget {
  const AnnouncementFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcements = ref.watch(announcementsProvider);
    return announcements.when(
      data: (items) => items.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EthioSectionLabel('Announcements'),
                for (final item in items)
                  EthioSectionCard(
                    children: [
                      Text(
                        item['title'] as String? ?? '',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(item['message'] as String? ?? ''),
                    ],
                  ),
              ],
            ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

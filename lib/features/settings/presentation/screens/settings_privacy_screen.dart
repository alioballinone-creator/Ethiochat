import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/env.dart';

import '../../../../core/design/design.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../chats/application/chat_providers.dart';
import '../../../contacts/domain/entities/contact_entity.dart';
import '../../../profile/application/profile_controller.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  Future<void> _pickAudience(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String current,
    required String kind,
  }) async {
    const audiences = ['Everyone', 'Contacts', 'Nobody'];
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final audience in audiences)
              ListTile(
                title: Text(audience),
                trailing: audience == current
                    ? const Icon(
                        Icons.check_rounded,
                        color: EthioColors.goldDeep,
                      )
                    : null,
                onTap: () => Navigator.pop(sheetContext, audience),
              ),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final settings = ref.read(appSettingsProvider);
    final next = switch (kind) {
      'lastSeen' => settings.copyWith(lastSeenAudience: choice),
      'photo' => settings.copyWith(profilePhotoAudience: choice),
      _ => settings.copyWith(groupAddAudience: choice),
    };
    await ref.read(appSettingsProvider.notifier).update(next);
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final data = await ref.read(chatRepositoryProvider).exportData();
    final json = const JsonEncoder.withIndent('  ').convert(data);
    await Clipboard.setData(ClipboardData(text: json));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your data export was copied to the clipboard.'),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This removes your profile, chats, contacts and wallet history from '
          'this device. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete everything',
              style: TextStyle(color: EthioColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref.read(chatRepositoryProvider).deleteAllData();
    if (!context.mounted) return;
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.failureOrNull?.message ?? 'Could not delete your data.',
          ),
        ),
      );
      return;
    }
    await ref.read(userProfileProvider.notifier).clear();
    await ref.read(appSettingsProvider.notifier).reset();
    if (Env.hasSupabase) {
      await Supabase.instance.client.auth.signOut();
    }
    if (!context.mounted) return;
    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = EthioPalette.of(context);
    final settings = ref.watch(appSettingsProvider);
    final contacts =
        ref.watch(contactsProvider).valueOrNull ?? const <ContactEntity>[];
    final blocked = contacts.where((c) => c.isBlocked).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Privacy and security',
            style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x2, bottom: Sp.x8),
          children: [
            EthioSectionCard(
              children: [
                EthioNavRow(
                  icon: Icons.visibility_outlined,
                  title: 'Last seen and online',
                  subtitle: settings.lastSeenAudience,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickAudience(
                    context,
                    ref,
                    title: 'Who can see when I was online?',
                    current: settings.lastSeenAudience,
                    kind: 'lastSeen',
                  ),
                ),
                EthioNavRow(
                  icon: Icons.account_circle_outlined,
                  title: 'Profile photo',
                  subtitle: settings.profilePhotoAudience,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickAudience(
                    context,
                    ref,
                    title: 'Who can see my profile photo?',
                    current: settings.profilePhotoAudience,
                    kind: 'photo',
                  ),
                ),
                EthioNavRow(
                  icon: Icons.group_add_outlined,
                  title: 'Add me to groups',
                  subtitle: settings.groupAddAudience,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickAudience(
                    context,
                    ref,
                    title: 'Who can add me to groups?',
                    current: settings.groupAddAudience,
                    kind: 'group',
                  ),
                  last: true,
                ),
              ],
            ),
            const EthioSectionLabel('Messaging'),
            EthioSectionCard(
              children: [
                EthioSwitchRow(
                  icon: Icons.done_all_rounded,
                  title: 'Read receipts',
                  subtitle: 'If off, you cannot see other people’s receipts',
                  value: settings.readReceipts,
                  onChanged: (value) => ref
                      .read(appSettingsProvider.notifier)
                      .update(settings.copyWith(readReceipts: value)),
                ),
                EthioSwitchRow(
                  icon: Icons.visibility_off_outlined,
                  title: 'Show last seen',
                  subtitle: 'Controls your online status',
                  value: settings.showLastSeen,
                  onChanged: (value) => ref
                      .read(appSettingsProvider.notifier)
                      .update(settings.copyWith(showLastSeen: value)),
                  last: true,
                ),
              ],
            ),
            const EthioSectionLabel('Blocking'),
            EthioSectionCard(
              children: [
                EthioNavRow(
                  icon: Icons.block_outlined,
                  title: 'Blocked contacts',
                  subtitle: blocked == 0
                      ? 'No blocked contacts'
                      : '$blocked blocked ${blocked == 1 ? 'contact' : 'contacts'}',
                  onTap: () => context.push('/me/settings/privacy/blocked'),
                  last: true,
                ),
              ],
            ),
            const EthioSectionLabel('Your data'),
            EthioSectionCard(
              children: [
                EthioNavRow(
                  icon: Icons.download_outlined,
                  title: 'Export my data',
                  subtitle: 'Copy a JSON archive to the clipboard',
                  onTap: () => _exportData(context, ref),
                ),
                EthioNavRow(
                  icon: Icons.delete_forever_outlined,
                  title: 'Delete my account',
                  subtitle: 'Remove this account and its local data',
                  onTap: () => _deleteAccount(context, ref),
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: Sp.x4),
            Container(
              padding: const EdgeInsets.all(Sp.x4),
              decoration: BoxDecoration(
                color: pal.chip,
                borderRadius: Rad.r18,
                border: Border.all(color: pal.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: EthioColors.goldDeep,
                  ),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: Text(
                      'Your personal messages and calls are protected in transit. '
                      'EthioChat never shows your phone number to people outside '
                      'your contacts.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: pal.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x3),
            TextButton(
              onPressed: () => context.push('/me/settings/privacy/blocked'),
              child: const Text('Manage blocked contacts'),
            ),
          ],
        ),
      ),
    );
  }
}

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  Future<void> _unblock(
    BuildContext context,
    WidgetRef ref,
    ContactEntity contact,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Unblock ${contact.displayName}?'),
        content: const Text(
          'They will be able to send you messages and call you again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await ref
        .read(chatRepositoryProvider)
        .setContactBlocked(contact.displayName, false);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? '${contact.displayName} unblocked.'
              : result.failureOrNull?.message ?? 'Could not unblock contact.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts =
        ref.watch(contactsProvider).valueOrNull ?? const <ContactEntity>[];
    final blocked = contacts.where((c) => c.isBlocked).toList(growable: false);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Blocked contacts',
            style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: blocked.isEmpty
            ? const EthioEmptyState(
                icon: Icons.block_outlined,
                title: 'No blocked contacts',
                message:
                    'People you block appear here. They cannot message you, '
                    'call you or see your updates.',
              )
            : ListView.separated(
                padding: Sp.screen.copyWith(top: Sp.x3, bottom: Sp.x8),
                itemCount: blocked.length,
                separatorBuilder: (_, __) => const SizedBox(height: Sp.x2),
                itemBuilder: (context, index) {
                  final contact = blocked[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: Rad.r14,
                      border: Border.all(color: EthioPalette.of(context).line),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Sp.x4,
                        vertical: Sp.x1,
                      ),
                      leading: EthioAvatar(name: contact.displayName, size: 44),
                      title: Text(contact.displayName),
                      subtitle: Text(contact.phoneE164 ?? 'Blocked contact'),
                      trailing: TextButton(
                        onPressed: () => _unblock(context, ref, contact),
                        child: const Text('Unblock'),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

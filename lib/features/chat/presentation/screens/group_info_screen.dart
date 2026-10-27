import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/db/app_database.dart' show GroupMember;
import '../../../../core/design/design.dart';
import '../../../chats/application/chat_providers.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  const GroupInfoScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  var _onlyAdminsSend = false;
  var _approveMembers = false;
  var _disappearing = 'Off';
  var _loaded = false;

  String get _prefix => 'group.${widget.chatId}.';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _onlyAdminsSend = prefs.getBool('${_prefix}onlyAdminsSend') ?? false;
        _approveMembers = prefs.getBool('${_prefix}approveMembers') ?? false;
        _disappearing = prefs.getString('${_prefix}disappearing') ?? 'Off';
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _setPreference(String key, Object value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) await prefs.setBool('$_prefix$key', value);
      if (value is String) await prefs.setString('$_prefix$key', value);
    } catch (_) {
      // The in-memory setting still applies for this session.
    }
  }

  Future<void> _addMember() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add member'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Member name'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.length < 2) return;
    final result = await ref
        .read(chatRepositoryProvider)
        .addGroupMember(widget.chatId, name);
    if (!mounted) return;
    _feedback(
      result.isSuccess
          ? '$name was added to the group.'
          : result.failureOrNull?.message ?? 'Could not add member.',
    );
  }

  Future<void> _memberActions(GroupMember member, bool isMe) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: EthioAvatar(name: member.displayName, size: 40),
              title: Text(member.displayName),
              subtitle: Text(
                member.role == 'admin' ? 'Group admin' : 'Group member',
              ),
            ),
            const Divider(height: 1),
            if (!isMe)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded),
                title: const Text('Send message'),
                onTap: () => Navigator.pop(sheetContext, 'message'),
              ),
            if (!isMe && member.role != 'admin')
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Make admin'),
                onTap: () => Navigator.pop(sheetContext, 'promote'),
              ),
            if (!isMe && member.role == 'admin')
              ListTile(
                leading: const Icon(Icons.remove_moderator_outlined),
                title: const Text('Dismiss as admin'),
                onTap: () => Navigator.pop(sheetContext, 'demote'),
              ),
            if (!isMe)
              ListTile(
                leading: const Icon(
                  Icons.person_remove_outlined,
                  color: EthioColors.danger,
                ),
                title: const Text(
                  'Remove from group',
                  style: TextStyle(color: EthioColors.danger),
                ),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final repo = ref.read(chatRepositoryProvider);
    switch (action) {
      case 'message':
        final result = await repo.openDirectChat(member.displayName);
        if (!mounted) return;
        final conversation = result.valueOrNull;
        if (conversation != null) {
          context.push('/chats/${conversation.id}');
        }
        break;
      case 'promote':
      case 'demote':
        await repo.setGroupMemberRole(
          widget.chatId,
          member.memberId,
          action == 'promote',
        );
        if (mounted) {
          _feedback(
            action == 'promote'
                ? '${member.displayName} is now an admin.'
                : '${member.displayName} is no longer an admin.',
          );
        }
        break;
      case 'remove':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Remove ${member.displayName}?'),
            content: const Text(
              'They will no longer receive messages from this group.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await repo.removeGroupMember(widget.chatId, member.memberId);
        if (mounted) _feedback('${member.displayName} removed.');
        break;
    }
  }

  Future<void> _shareInvite() async {
    await Clipboard.setData(
      ClipboardData(text: 'https://ethiochat.et/join/${widget.chatId}'),
    );
    if (!mounted) return;
    _feedback('Invite link copied.');
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete group?'),
        content: const Text(
          'This removes the group and its messages from this device for you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: EthioColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(chatRepositoryProvider).deleteConversation(widget.chatId);
    if (!mounted) return;
    context.go('/chats');
  }

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final conversation = ref.watch(conversationProvider(widget.chatId));
    final title = conversation.valueOrNull?.title ?? 'Group';
    final members =
        ref.watch(groupMembersProvider(widget.chatId)).valueOrNull ??
            const <GroupMember>[];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Group info', style: text.headlineMedium),
        actions: [
          IconButton(
            tooltip: 'Invite link',
            icon: const Icon(Icons.link_rounded),
            onPressed: _shareInvite,
          ),
          const SizedBox(width: Sp.x1),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x2, bottom: Sp.x8),
          children: [
            Center(
              child: Column(
                children: [
                  EthioAvatar(name: title, size: 88),
                  const SizedBox(height: Sp.x3),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: text.headlineSmall,
                  ),
                  const SizedBox(height: Sp.x1),
                  Text(
                    '${members.length} members',
                    style: text.bodyMedium?.copyWith(color: pal.textSecondary),
                  ),
                  const SizedBox(height: Sp.x3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _HeaderAction(
                        icon: Icons.person_add_alt_1_outlined,
                        label: 'Add',
                        onTap: _addMember,
                      ),
                      const SizedBox(width: Sp.x4),
                      _HeaderAction(
                        icon: Icons.search_rounded,
                        label: 'Search',
                        onTap: () => context.push('/search'),
                      ),
                      const SizedBox(width: Sp.x4),
                      _HeaderAction(
                        icon: Icons.call_outlined,
                        label: 'Call',
                        onTap: () =>
                            context.push('/call/${widget.chatId}?video=true'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x6),
            EthioSectionLabel(
              'Members',
              trailing: TextButton(
                onPressed: _addMember,
                child: const Text('Add member'),
              ),
            ),
            EthioSectionCard(
              children: [
                for (var i = 0; i < members.length; i++)
                  ListTile(
                    onTap: () => _memberActions(
                      members[i],
                      members[i].memberId == 'me',
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Sp.x4,
                      vertical: Sp.x1,
                    ),
                    leading:
                        EthioAvatar(name: members[i].displayName, size: 44),
                    title: Text(
                      members[i].memberId == 'me'
                          ? '${members[i].displayName} (you)'
                          : members[i].displayName,
                      style: text.titleMedium,
                    ),
                    subtitle: Text(
                      members[i].role == 'admin' ? 'Admin' : 'Member',
                      style:
                          text.labelSmall?.copyWith(color: pal.textSecondary),
                    ),
                    trailing: members[i].role == 'admin'
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Sp.x2,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: EthioColors.gold.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Admin',
                              style: text.labelSmall
                                  ?.copyWith(color: EthioColors.goldDeep),
                            ),
                          )
                        : const Icon(Icons.more_horiz_rounded),
                  ),
                ListTile(
                  onTap: _addMember,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Sp.x4,
                    vertical: Sp.x1,
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: pal.chip,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: pal.line),
                    ),
                    child: const Icon(Icons.add_rounded),
                  ),
                  title: Text('Add member', style: text.titleMedium),
                ),
              ],
            ),
            const EthioSectionLabel('Admin tools'),
            EthioSectionCard(
              children: [
                EthioSwitchRow(
                  icon: Icons.campaign_outlined,
                  title: 'Only admins can send',
                  subtitle: 'Members can read but not post',
                  value: _onlyAdminsSend,
                  onChanged: _loaded
                      ? (value) {
                          setState(() => _onlyAdminsSend = value);
                          _setPreference('onlyAdminsSend', value);
                        }
                      : (_) {},
                ),
                EthioSwitchRow(
                  icon: Icons.how_to_reg_outlined,
                  title: 'Approve new members',
                  subtitle: 'Admins must accept invites',
                  value: _approveMembers,
                  onChanged: _loaded
                      ? (value) {
                          setState(() => _approveMembers = value);
                          _setPreference('approveMembers', value);
                        }
                      : (_) {},
                  last: true,
                ),
                EthioNavRow(
                  icon: Icons.timer_outlined,
                  title: 'Disappearing messages',
                  subtitle: _disappearing,
                  onTap: _pickDisappearing,
                ),
                EthioNavRow(
                  icon: Icons.push_pin_outlined,
                  title: 'Pinned messages',
                  subtitle: 'Keep important updates on top',
                  onTap: () => _feedback('No pinned messages in this group.'),
                  last: true,
                ),
              ],
            ),
            const EthioSectionLabel('Danger zone'),
            EthioSectionCard(
              children: [
                EthioNavRow(
                  icon: Icons.exit_to_app_rounded,
                  title: 'Exit group',
                  subtitle: 'Stop receiving messages',
                  onTap: _deleteGroup,
                ),
                EthioNavRow(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete group for me',
                  subtitle: 'Remove this group from your chats',
                  onTap: _deleteGroup,
                  last: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDisappearing() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const ['Off', '24 hours', '7 days', '90 days'])
              ListTile(
                title: Text(option),
                trailing: option == _disappearing
                    ? const Icon(
                        Icons.check_rounded,
                        color: EthioColors.goldDeep,
                      )
                    : null,
                onTap: () => Navigator.pop(sheetContext, option),
              ),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
    if (choice == null) return;
    setState(() => _disappearing = choice);
    await _setPreference('disappearing', choice);
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: Rad.r14,
      child: Padding(
        padding: const EdgeInsets.all(Sp.x2),
        child: Column(
          children: [
            EthioIconTile(icon: icon),
            const SizedBox(height: Sp.x1),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

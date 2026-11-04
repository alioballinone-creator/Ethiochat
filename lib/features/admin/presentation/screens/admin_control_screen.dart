import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/design.dart';
import '../../data/admin_repository.dart';

enum _AdminSection {
  dashboard('Dashboard', Icons.dashboard_outlined, 'dashboard'),
  users('Users', Icons.people_outline, 'users.list'),
  staff('Staff and roles', Icons.badge_outlined, 'staff.list'),
  content('Content control', Icons.fact_check_outlined, 'content.list'),
  reports('Reports', Icons.flag_outlined, 'reports.list'),
  support('Support', Icons.support_agent_outlined, 'tickets.list'),
  announcements('Announcements', Icons.campaign_outlined, 'announcements.list'),
  finance('Finance', Icons.account_balance_wallet_outlined, 'finance.list'),
  settings('App settings', Icons.tune_outlined, 'settings.list'),
  audit('Audit log', Icons.receipt_long_outlined, 'audit.list');

  const _AdminSection(this.label, this.icon, this.action);

  final String label;
  final IconData icon;
  final String action;
}

class AdminControlScreen extends StatefulWidget {
  const AdminControlScreen({super.key});

  @override
  State<AdminControlScreen> createState() => _AdminControlScreenState();
}

class _AdminControlScreenState extends State<AdminControlScreen> {
  final _repository = AdminRepository();
  final _search = TextEditingController();
  final _inviteEmail = TextEditingController();
  final _announcementTitle = TextEditingController();
  final _announcementMessage = TextEditingController();
  _AdminSection _section = _AdminSection.dashboard;
  Map<String, dynamic> _data = const {};
  String _staffRole = 'support';
  String _contentTable = 'moments';
  String _announcementAudience = 'all';
  String _financeStatus = 'all';
  Set<String> _allowedSections = {'dashboard'};
  Set<String> _allowedActions = {'dashboard'};
  String? _error;
  bool _loading = true;
  bool _saving = false;

  static const _staffRoles = [
    'owner',
    'admin',
    'moderator',
    'support',
    'finance',
    'content',
  ];
  static const _audiences = [
    'all',
    'user',
    'owner',
    'admin',
    'moderator',
    'support',
    'finance',
    'content',
  ];
  static const _contentTables = [
    'moments',
    'messages',
    'channel_posts',
    'oa_posts',
    'mini_programs',
  ];
  static const _financeStatuses = [
    'all',
    'pending',
    'success',
    'failed',
    'reversed',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _inviteEmail.dispose();
    _announcementTitle.dispose();
    _announcementMessage.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final access = await _repository.call('access');
      final allowed =
          (access['sections'] as List? ?? const []).whereType<String>().toSet();
      final actions =
          (access['actions'] as List? ?? const []).whereType<String>().toSet();
      final selected = allowed.contains(_section.action)
          ? _section
          : _AdminSection.values.firstWhere(
              (section) => allowed.contains(section.action),
              orElse: () => _AdminSection.dashboard,
            );
      final body = switch (selected) {
        _AdminSection.users => {'search': _search.text.trim()},
        _AdminSection.content => {'table': _contentTable},
        _AdminSection.finance => {'status': _financeStatus},
        _ => const <String, dynamic>{},
      };
      final result = await _repository.call(selected.action, body: body);
      if (!mounted) return;
      setState(() {
        _allowedSections = allowed;
        _allowedActions = actions;
        _section = selected;
        _data = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(error);
        _data = const {};
        _loading = false;
      });
    }
  }

  String _errorMessage(Object error) {
    if (error is FunctionException && error.details is Map) {
      final message = (error.details as Map)['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return 'This section could not be loaded. Check your staff permissions and connection.';
  }

  Future<void> _run(String action, Map<String, dynamic> body) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository.call(action, body: body);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved.')));
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Map<String, dynamic>> _rows(String key) {
    final value = _data[key];
    if (value is! List) return const [];
    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  String _text(Object? value, [String fallback = 'Not provided']) =>
      value == null || value.toString().isEmpty ? fallback : value.toString();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin control', style: text.titleLarge),
        leading: wide
            ? null
            : Builder(
                builder: (context) => IconButton(
                  tooltip: 'Open admin sections',
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
        actions: [
          IconButton(
            tooltip: 'Refresh section',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      drawer: wide
          ? null
          : Drawer(child: _navigation(context, closeOnSelect: true)),
      body: Row(
        children: [
          if (wide) SizedBox(width: 248, child: _navigation(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionHeader(context),
                if (_error != null) _errorBanner(context, _error!),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _sectionBody(context),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navigation(BuildContext context, {bool closeOnSelect = false}) {
    final pal = EthioPalette.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
            child: Text(
              'ETHIOCHAT / OPS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: pal.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final section in _AdminSection.values.where(
                  (section) => _allowedSections.contains(section.action),
                ))
                  ListTile(
                    selected: _section == section,
                    leading: Icon(section.icon),
                    title: Text(section.label),
                    onTap: () {
                      setState(() => _section = section);
                      if (closeOnSelect) Navigator.pop(context);
                      _load();
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sign out'),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted)
                Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Icon(_section.icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _section.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_section == _AdminSection.users)
            SizedBox(
              width: 280,
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search users',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: IconButton(
                    tooltip: 'Search users',
                    onPressed: _load,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  ),
                ),
                onSubmitted: (_) => _load(),
              ),
            ),
          if (_section == _AdminSection.content)
            _enumPicker(_contentTable, _contentTables, (value) {
              setState(() => _contentTable = value);
              _load();
            }),
          if (_section == _AdminSection.finance)
            _enumPicker(_financeStatus, _financeStatuses, (value) {
              setState(() => _financeStatus = value);
              _load();
            }),
        ],
      ),
    );
  }

  Widget _enumPicker(
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButton<String>(
      value: value,
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
      items: [
        for (final item in options)
          DropdownMenuItem(value: item, child: Text(item.replaceAll('_', ' '))),
      ],
    );
  }

  Widget _sectionBody(BuildContext context) {
    final children = switch (_section) {
      _AdminSection.dashboard => _dashboard(context),
      _AdminSection.users => _users(context),
      _AdminSection.staff => _staff(context),
      _AdminSection.content => _content(context),
      _AdminSection.reports => _reports(context),
      _AdminSection.support => _tickets(context),
      _AdminSection.announcements => _announcements(context),
      _AdminSection.finance => _finance(context),
      _AdminSection.settings => _settings(context),
      _AdminSection.audit => _audit(context),
    };
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: children,
    );
  }

  List<Widget> _dashboard(BuildContext context) {
    const metrics = <(String, String, IconData)>[
      ('Users', 'users', Icons.people_outline),
      ('Active 30d', 'activeUsers', Icons.bolt_outlined),
      ('New today', 'newUsersToday', Icons.person_add_alt_outlined),
      ('Messages today', 'messagesToday', Icons.forum_outlined),
      ('Open reports', 'reportsOpen', Icons.flag_outlined),
      ('Transactions', 'transactions', Icons.receipt_long_outlined),
    ];
    return [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final metric in metrics)
            SizedBox(
              width: 220,
              child: EthioSectionCard(
                children: [
                  Row(
                    children: [
                      EthioIconTile(icon: metric.$3),
                      const SizedBox(width: 12),
                      Expanded(child: Text(metric.$1)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _text(_data[metric.$2], '0'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
        ],
      ),
    ];
  }

  List<Widget> _users(BuildContext context) => [
        for (final user in _rows('users'))
          EthioSectionCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child:
                      Text(_text(user['display_name'], '?')[0].toUpperCase()),
                ),
                title: Text(_text(user['display_name'], 'Unnamed account')),
                subtitle: Text(
                  '${_text(user['email'], 'No email')} · ${_text(user['role'], 'user')}',
                ),
                onTap: () => _showUserDetails(user),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Manage account',
                  onSelected: (action) {
                    if (action == 'activity') _showActivity(user);
                    if (action == 'disable' || action == 'enable') {
                      _run('users.set-status', {
                        'userId': user['id'],
                        'enabled': action == 'enable',
                      });
                    }
                    if (action.startsWith('role:')) {
                      _run('users.set-role', {
                        'userId': user['id'],
                        'role': action.substring(5),
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    if (_allowedActions.contains('users.activity'))
                      const PopupMenuItem(
                        value: 'activity',
                        child: Text('View activity'),
                      ),
                    if (_allowedActions.contains('users.set-status'))
                      PopupMenuItem(
                        value:
                            user['bannedUntil'] == null ? 'disable' : 'enable',
                        child: Text(
                          user['bannedUntil'] == null
                              ? 'Disable account'
                              : 'Enable account',
                        ),
                      ),
                    if (_allowedActions.contains('users.set-role'))
                      for (final role in ['user', ..._staffRoles])
                        PopupMenuItem(
                          value: 'role:$role',
                          child: Text('Set role: $role'),
                        ),
                  ],
                ),
              ),
            ],
          ),
        if (_rows('users').isEmpty) _empty('No users found.'),
      ];

  List<Widget> _staff(BuildContext context) => [
        EthioSectionCard(
          children: [
            Text(
              'Create staff access',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inviteEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Work email'),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _staffRole,
                  onChanged: (value) =>
                      setState(() => _staffRole = value ?? _staffRole),
                  items: [
                    for (final role in _staffRoles)
                      DropdownMenuItem(value: role, child: Text(role)),
                  ],
                ),
                IconButton.filled(
                  tooltip: 'Send invitation',
                  onPressed:
                      _saving || !_allowedActions.contains('staff.invite')
                          ? null
                          : () => _run('staff.invite', {
                                'email': _inviteEmail.text.trim(),
                                'role': _staffRole,
                              }),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final staff in _rows('staff'))
          EthioSectionCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _text(
                    (staff['profile'] as Map?)?['display_name'],
                    _text(staff['user_id']),
                  ),
                ),
                subtitle: Text('Role: ${_text(staff['role'])}'),
                trailing: IconButton(
                  tooltip: 'Remove staff role',
                  onPressed: _saving ||
                          !_allowedActions.contains('staff.remove')
                      ? null
                      : () =>
                          _run('staff.remove', {'userId': staff['user_id']}),
                  icon: const Icon(Icons.person_remove_outlined),
                ),
              ),
            ],
          ),
        if (_rows('staff').isEmpty) _empty('No staff roles are assigned.'),
      ];

  List<Widget> _content(BuildContext context) => [
        for (final item in _rows('items'))
          EthioSectionCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _text(
                    item['title'],
                    _text(
                      item['caption'],
                      _text(item['body'], _text(item['type'], 'Content item')),
                    ),
                  ),
                ),
                subtitle: Text(
                  'ID ${_text(item['id'])} · ${_text(item['created_at'])}',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (_allowedActions.contains('content.moderate'))
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _run('content.moderate', {
                                'table': _contentTable,
                                'id': item['id'],
                                'status': 'hidden',
                              }),
                      icon: const Icon(Icons.visibility_off_outlined),
                      label: const Text('Hide'),
                    ),
                  if (_allowedActions.contains('content.moderate'))
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _run('content.moderate', {
                                'table': _contentTable,
                                'id': item['id'],
                                'status': 'approved',
                              }),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Approve'),
                    ),
                  if (_allowedActions.contains('content.moderate'))
                    OutlinedButton.icon(
                      onPressed:
                          _saving ? null : () => _confirmDeleteContent(item),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                ],
              ),
            ],
          ),
        if (_rows('items').isEmpty) _empty('No content items found.'),
      ];

  List<Widget> _reports(BuildContext context) => [
        for (final report in _rows('reports'))
          EthioSectionCard(
            children: [
              Text(
                '${_text(report['target_type'])} · ${_text(report['target_name'], _text(report['target_id']))}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text('${_text(report['reason'])}\n${_text(report['note'], '')}'),
              if (report['staff_reply'] != null)
                Text('Reply: ${report['staff_reply']}'),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _allowedActions.contains('reports.update')
                      ? () => _editReport(report)
                      : null,
                  icon: const Icon(Icons.reply_outlined),
                  label: Text('${_text(report['status'])} · Reply'),
                ),
              ),
            ],
          ),
        if (_rows('reports').isEmpty) _empty('No reports are in the queue.'),
      ];

  List<Widget> _tickets(BuildContext context) => [
        for (final ticket in _rows('tickets'))
          EthioSectionCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_text(ticket['subject'])),
                subtitle: Text(
                  'Status: ${_text(ticket['status'])} · User ${_text(ticket['user_id'])}',
                ),
                trailing: IconButton(
                  tooltip: 'Manage ticket and reply',
                  onPressed: _allowedActions.contains('tickets.update') ||
                          _allowedActions.contains('tickets.reply')
                      ? () => _editTicket(ticket)
                      : null,
                  icon: const Icon(Icons.open_in_new_rounded),
                ),
              ),
              for (final message
                  in (ticket['ticket_messages'] as List? ?? const [])
                      .whereType<Map>()
                      .take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${_text(message['sender_id'])}: ${_text(message['body'])}',
                  ),
                ),
            ],
          ),
        if (_rows('tickets').isEmpty) _empty('No support tickets.'),
      ];

  List<Widget> _announcements(BuildContext context) => [
        EthioSectionCard(
          children: [
            TextField(
              controller: _announcementTitle,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _announcementMessage,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Audience'),
                const SizedBox(width: 12),
                _enumPicker(
                  _announcementAudience,
                  _audiences,
                  (value) => setState(() => _announcementAudience = value),
                ),
                const Spacer(),
                TextButton(
                  onPressed:
                      _saving || !_allowedActions.contains('announcements.save')
                          ? null
                          : () => _saveAnnouncement('draft'),
                  child: const Text('Save draft'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed:
                      _saving || !_allowedActions.contains('announcements.save')
                          ? null
                          : () => _saveAnnouncement('published'),
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Publish'),
                ),
              ],
            ),
          ],
        ),
        for (final item in _rows('announcements'))
          EthioSectionCard(
            children: [
              Text(
                _text(item['title']),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(_text(item['message'])),
              const SizedBox(height: 4),
              Text('${_text(item['audience'])} · ${_text(item['status'])}'),
            ],
          ),
        if (_rows('announcements').isEmpty) _empty('No announcements yet.'),
      ];

  List<Widget> _finance(BuildContext context) {
    final totals =
        (_data['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return [
      Wrap(
        spacing: 12,
        children: [
          for (final entry in totals.entries)
            Chip(label: Text('${entry.key}: ${entry.value} minor units')),
        ],
      ),
      for (final transaction in _rows('transactions'))
        EthioSectionCard(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${_text(transaction['type'])} · ${transaction['amount_minor']} minor units',
              ),
              subtitle: Text(
                '${_text(transaction['status'])} · ${_text(transaction['provider'])} · ${_text(transaction['created_at'])}',
              ),
              trailing: transaction['status'] == 'pending' &&
                      ['topup', 'bill'].contains(transaction['type']) &&
                      _allowedActions.contains('finance.review')
                  ? PopupMenuButton<String>(
                      tooltip: 'Review transaction',
                      onSelected: (decision) => _run('finance.review', {
                        'id': transaction['id'],
                        'decision': decision,
                      }),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'approve', child: Text('Approve')),
                        PopupMenuItem(value: 'reject', child: Text('Reject')),
                      ],
                    )
                  : null,
            ),
          ],
        ),
      if (_rows('transactions').isEmpty)
        _empty('No transactions match this filter.'),
    ];
  }

  List<Widget> _settings(BuildContext context) => [
        for (final flag in _rows('flags'))
          EthioSectionCard(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(_text(flag['key'])),
                subtitle:
                    Text(_text(flag['description'], 'Feature availability')),
                value: flag['enabled'] == true,
                onChanged:
                    _saving || !_allowedActions.contains('settings.update')
                        ? null
                        : (enabled) => _run('settings.update', {
                              'key': flag['key'],
                              'enabled': enabled,
                            }),
              ),
            ],
          ),
        if (_rows('flags').isEmpty) _empty('No feature flags are configured.'),
      ];

  List<Widget> _audit(BuildContext context) => [
        for (final entry in _rows('entries'))
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: Text(_text(entry['action'])),
            subtitle: Text(
              '${_text(entry['actor_id'])} · ${_text(entry['target_type'])} ${_text(entry['target_id'], '')} · ${_text(entry['created_at'])}\n${jsonEncode(entry['metadata'] ?? const {})}',
            ),
            isThreeLine: true,
          ),
        if (_rows('entries').isEmpty) _empty('No audit entries.'),
      ];

  Widget _empty(String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text(message)),
      );

  Widget _errorBanner(BuildContext context, String message) => MaterialBanner(
        content: Text(message),
        leading: const Icon(Icons.error_outline_rounded),
        actions: [TextButton(onPressed: _load, child: const Text('Retry'))],
      );

  Future<void> _showUserDetails(Map<String, dynamic> user) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text(user['display_name'], 'Account profile')),
        content: Text(
          [
            'ID: ${_text(user['id'])}',
            'Ethio ID: ${_text(user['ethio_id'])}',
            'Email: ${_text(user['email'])}',
            'Role: ${_text(user['role'])}',
            'Created: ${_text(user['created_at'])}',
            'Last active: ${_text(user['last_seen_at'])}',
            'Disabled: ${user['bannedUntil'] != null}',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showActivity(Map<String, dynamic> user) async {
    try {
      final activity = await _repository.call(
        'users.activity',
        body: {'userId': user['id']},
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Activity · ${_text(user['display_name'])}'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Text(const JsonEncoder.withIndent('  ').convert(activity)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    }
  }

  Future<void> _confirmDeleteContent(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete content?'),
        content: const Text('This action removes the content from user feeds.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run('content.moderate', {
        'table': _contentTable,
        'id': item['id'],
        'status': 'deleted',
      });
    }
  }

  Future<void> _editReport(Map<String, dynamic> report) async {
    var status = _text(report['status'], 'open');
    final reply = TextEditingController(text: _text(report['staff_reply'], ''));
    final result = await showDialog<(String, String)?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: status,
              items: const ['open', 'reviewing', 'resolved', 'dismissed']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => status = value ?? status,
            ),
            TextField(
              controller: reply,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Reply to reporter'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (status, reply.text)),
            child: const Text('Save review'),
          ),
        ],
      ),
    );
    reply.dispose();
    if (result != null)
      await _run('reports.update', {
        'id': report['id'],
        'status': result.$1,
        'reply': result.$2,
      });
  }

  Future<void> _editTicket(Map<String, dynamic> ticket) async {
    var status = _text(ticket['status'], 'open');
    final reply = TextEditingController();
    final result = await showDialog<(String, String)?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text(ticket['subject'], 'Support ticket')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: status,
              items: const ['open', 'assigned', 'resolved']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => status = value ?? status,
            ),
            TextField(
              controller: reply,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Reply to user'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (status, reply.text)),
            child: const Text('Update ticket'),
          ),
        ],
      ),
    );
    reply.dispose();
    if (result == null) return;
    await _run('tickets.update', {
      'id': ticket['id'],
      'status': result.$1,
      'assignedTo': Supabase.instance.client.auth.currentUser?.id,
    });
    if (result.$2.trim().isNotEmpty) {
      await _run('tickets.reply', {'id': ticket['id'], 'reply': result.$2});
    }
  }

  Future<void> _saveAnnouncement(String status) async {
    await _run('announcements.save', {
      'title': _announcementTitle.text.trim(),
      'message': _announcementMessage.text.trim(),
      'audience': _announcementAudience,
      'status': status,
    });
    if (_error == null && mounted) {
      _announcementTitle.clear();
      _announcementMessage.clear();
    }
  }
}

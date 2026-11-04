import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/design.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _replies = <String, TextEditingController>{};
  List<Map<String, dynamic>> _tickets = const [];
  String? _error;
  bool _loading = true;
  bool _sending = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    for (final controller in _replies.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Sign in to contact support.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _client
          .from('tickets')
          .select('id,subject,status,created_at,updated_at,ticket_messages(id,sender_id,body,created_at)')
          .eq('user_id', user.id)
          .order('updated_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _tickets = rows.map((row) => Map<String, dynamic>.from(row)).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Support requests are unavailable. Try again shortly.';
        _loading = false;
      });
    }
  }

  Future<void> _createTicket() async {
    final user = _client.auth.currentUser;
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    if (user == null) {
      setState(() => _error = 'Sign in to contact support.');
      return;
    }
    if (subject.isEmpty || message.isEmpty) {
      setState(() => _error = 'Enter a subject and message.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _client.rpc('create_support_ticket', params: {
        'p_subject': subject,
        'p_message': message,
      });
      _subject.clear();
      _message.clear();
      await _load();
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Your support message could not be sent.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _reply(Map<String, dynamic> ticket) async {
    final user = _client.auth.currentUser;
    final text = _replies[ticket['id']]?.text.trim() ?? '';
    if (user == null || text.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _client.rpc('reply_support_ticket', params: {
        'p_ticket': ticket['id'],
        'p_message': text,
      });
      _replies[ticket['id']]?.clear();
      await _load();
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Your reply could not be sent.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('Support requests', style: text.titleLarge)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    EthioSectionCard(
                      children: [
                        Text('New request', style: text.titleMedium),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _subject,
                          maxLength: 160,
                          decoration: const InputDecoration(labelText: 'Subject'),
                        ),
                        TextField(
                          controller: _message,
                          minLines: 3,
                          maxLines: 6,
                          maxLength: 5000,
                          decoration: const InputDecoration(labelText: 'Message'),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _sending ? null : _createTicket,
                          icon: _sending
                              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send_rounded),
                          label: const Text('Send to support'),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: text.bodySmall?.copyWith(color: EthioColors.danger)),
                    ],
                    const EthioSectionLabel('Your requests'),
                    for (final ticket in _tickets) ...[
                      EthioSectionCard(
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('${ticket['subject']}', style: text.titleSmall)),
                              Chip(label: Text('${ticket['status']}')),
                            ],
                          ),
                          for (final row in (ticket['ticket_messages'] as List? ?? const []).whereType<Map>())
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Align(
                                alignment: row['sender_id'] == _client.auth.currentUser?.id
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Text('${row['body']}'),
                              ),
                            ),
                          if (ticket['status'] != 'resolved') ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: _replies.putIfAbsent(ticket['id'] as String, TextEditingController.new),
                              minLines: 1,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Reply',
                                suffixIcon: IconButton(
                                  tooltip: 'Send reply',
                                  onPressed: _sending ? null : () => _reply(ticket),
                                  icon: const Icon(Icons.send_rounded),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (_tickets.isEmpty) const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('No support requests yet.')),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

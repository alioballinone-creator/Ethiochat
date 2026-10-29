import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/demo/demo_content.dart';
import '../../../../core/design/design.dart';
import '../../../chats/application/chat_providers.dart';

class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen> {
  var _status = PermissionStatus.denied;
  var _checking = true;
  var _shareLocation = false;
  var _opening = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.locationWhenInUse.status;
    if (!mounted) return;
    setState(() {
      _status = status;
      _checking = false;
    });
  }

  Future<void> _request() async {
    final status = await Permission.locationWhenInUse.request();
    if (!mounted) return;
    setState(() => _status = status);
  }

  Future<void> _openChat(DemoPerson person) async {
    if (_opening) return;
    setState(() => _opening = true);
    final result =
        await ref.read(chatRepositoryProvider).openDirectChat(person.name);
    if (!mounted) return;
    setState(() => _opening = false);
    final conversation = result.valueOrNull;
    if (conversation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.failureOrNull?.message ?? 'Could not open chat'),
        ),
      );
      return;
    }
    context.push('/chats/${conversation.id}');
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final granted = _status.isGranted;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('People nearby', style: text.headlineMedium),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _checkPermission,
          ),
          const SizedBox(width: Sp.x1),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _checking
            ? const ContactListSkeleton(count: 4)
            : granted
                ? ListView(
                    padding: Sp.screen.copyWith(top: Sp.x3, bottom: Sp.x8),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(Sp.x4),
                        decoration: BoxDecoration(
                          color: pal.chip,
                          borderRadius: Rad.r18,
                          border: Border.all(color: pal.line),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const EthioIconTile(
                                  icon: Icons.near_me_outlined,
                                  background: EthioColors.gold,
                                ),
                                const SizedBox(width: Sp.x3),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Share my location',
                                        style: text.titleMedium,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Only people nearby can see you.',
                                        style: text.labelSmall?.copyWith(
                                          color: pal.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: _shareLocation,
                                  activeTrackColor: EthioColors.gold,
                                  onChanged: (value) =>
                                      setState(() => _shareLocation = value),
                                ),
                              ],
                            ),
                            if (_shareLocation) ...[
                              const SizedBox(height: Sp.x3),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 16,
                                    color: EthioColors.success,
                                  ),
                                  const SizedBox(width: Sp.x1),
                                  Text(
                                    'Visible to people within 3 km',
                                    style: text.labelSmall?.copyWith(
                                      color: pal.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: Sp.x4),
                      Row(
                        children: [
                          Text('Around you', style: text.titleMedium),
                          const Spacer(),
                          Text(
                            'Distances are approximate',
                            style: text.labelSmall
                                ?.copyWith(color: pal.textTertiary),
                          ),
                        ],
                      ),
                      const SizedBox(height: Sp.x2),
                      for (final person in DemoContent.nearby)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Sp.x2),
                          child: Material(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: Rad.r18,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: Sp.x4,
                                vertical: Sp.x2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: Rad.r18,
                                side: BorderSide(color: pal.line),
                              ),
                              leading: EthioAvatar(name: person.name, size: 52),
                              title: Text(
                                person.name,
                                style: text.titleMedium,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    person.bio,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodySmall?.copyWith(
                                      color: pal.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${person.distance} away · '
                                    '${person.mutual} mutual friends',
                                    style: text.labelSmall?.copyWith(
                                      color: pal.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton.filledTonal(
                                tooltip: 'Say hello',
                                onPressed:
                                    _opening ? null : () => _openChat(person),
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : EthioEmptyState(
                    icon: Icons.location_off_outlined,
                    title: 'Location is off',
                    message: 'Turn on location to see people who are open to '
                        'meeting nearby. Your exact position is never shared.',
                    action: EthioButton(
                      label: _status.isPermanentlyDenied
                          ? 'Open settings'
                          : 'Allow location',
                      expand: false,
                      icon: Icons.my_location_rounded,
                      onPressed: _status.isPermanentlyDenied
                          ? openAppSettings
                          : _request,
                    ),
                  ),
      ),
    );
  }
}

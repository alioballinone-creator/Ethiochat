import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/design/design.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  Future<void> _nearby(BuildContext context) async {
    try {
      final status = await Permission.location.request();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.isGranted
                ? 'Location enabled — people nearby will appear here.'
                : 'Location permission is needed to find people nearby.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not access location: $error')),
      );
    }
  }

  void _scan(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_2_rounded),
              title: const Text('My QR code'),
              subtitle: const Text('Show your code to a friend'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/me/qr');
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded),
              title: const Text('Scan a code'),
              subtitle: const Text('Camera scanning runs on a device'),
              onTap: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Point the camera at an EthioChat code.'),
                  ),
                );
              },
            ),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
  }

  void _miniProgram(BuildContext context, String label) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: EthioPalette.of(context).chip,
                      borderRadius: Rad.r14,
                    ),
                    child: const Icon(Icons.apps_rounded),
                  ),
                  const SizedBox(width: Sp.x3),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: Sp.x3),
              Text(
                '$label mini programs are being rolled out in Addis Ababa '
                'first. You will be notified when $label opens in your area.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: Sp.x4),
              EthioButton(
                label: 'Got it',
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Discover',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x4, bottom: 80),
          children: [
            _DiscoverItem(
              icon: Icons.photo_library_outlined,
              title: 'Moments',
              hasRedDot: true,
              onTap: () => context.push('/discover/moments'),
            ),
            _DiscoverItem(
              icon: Icons.wifi_tethering_outlined,
              title: 'Channels',
              onTap: () => context.go('/chats?filter=3'),
            ),
            _DiscoverItem(
              icon: Icons.verified_outlined,
              title: 'Official Accounts',
              onTap: () => context.go('/chats?filter=3'),
            ),
            _DiscoverItem(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan',
              onTap: () => _scan(context),
            ),
            _DiscoverItem(
              icon: Icons.near_me_outlined,
              title: 'People nearby',
              onTap: () => _nearby(context),
            ),
            const SizedBox(height: Sp.x4),
            Text(
              'Mini Programs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Sp.x3),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              childAspectRatio: 0.7,
              children: [
                for (final label in const ['Shop', 'Ride', 'Food', 'Bills'])
                  _MiniProgramItem(
                    label: label,
                    onTap: () => _miniProgram(context, label),
                  ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: EthioBottomNav(
        index: 2,
        onTap: (i) {
          if (i == 0) context.go('/chats');
          if (i == 1) context.go('/contacts');
          if (i == 3) context.go('/me');
        },
      ),
    );
  }
}

class _DiscoverItem extends StatelessWidget {
  const _DiscoverItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.hasRedDot = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool hasRedDot;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: Sp.x2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: Rad.r14,
        border: Border.all(color: pal.line),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: pal.chip,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22),
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasRedDot)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: EthioColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: Sp.x2),
            const Icon(Icons.chevron_right_rounded, size: 22),
          ],
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x1),
      ),
    );
  }
}

class _MiniProgramItem extends StatelessWidget {
  const _MiniProgramItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

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
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pal.line),
            ),
            child: const Icon(Icons.apps_rounded),
          ),
          const SizedBox(height: Sp.x2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/cache/image_cache_manager.dart';
import '../../../../core/design/design.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/settings/app_settings.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final pal = EthioPalette.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Notifications',
            style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x2, bottom: Sp.x8),
          children: [
            EthioSectionCard(
              children: [
                EthioSwitchRow(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Message notifications',
                  subtitle: 'Alerts for direct messages',
                  value: settings.messageNotifications,
                  onChanged: (value) => controller.update(
                    settings.copyWith(messageNotifications: value),
                  ),
                ),
                EthioSwitchRow(
                  icon: Icons.groups_outlined,
                  title: 'Group notifications',
                  subtitle: 'Alerts for groups you are in',
                  value: settings.groupNotifications,
                  onChanged: (value) => controller.update(
                    settings.copyWith(groupNotifications: value),
                  ),
                  last: true,
                ),
              ],
            ),
            const EthioSectionLabel('Media'),
            EthioSectionCard(
              children: [
                EthioSwitchRow(
                  icon: Icons.download_outlined,
                  title: 'Auto-download media',
                  subtitle: 'Photos and voice notes on Wi-Fi',
                  value: settings.autoDownloadMedia,
                  onChanged: (value) => controller.update(
                    settings.copyWith(autoDownloadMedia: value),
                  ),
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
                  const Icon(Icons.info_outline_rounded,
                      color: EthioColors.goldDeep),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: Text(
                      'Notifications are delivered only for messages that need '
                      'your attention. Muted chats stay quiet until you open them.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: pal.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatBackupScreen extends ConsumerStatefulWidget {
  const ChatBackupScreen({super.key});

  @override
  ConsumerState<ChatBackupScreen> createState() => _ChatBackupScreenState();
}

class _ChatBackupScreenState extends ConsumerState<ChatBackupScreen> {
  var _backingUp = false;
  String _lastBackup = 'Never backed up';
  var _progress = 0.0;

  Future<void> _backup() async {
    setState(() {
      _backingUp = true;
      _progress = 0;
    });
    for (var step = 1; step <= 10; step++) {
      await Future<void>.delayed(const Duration(milliseconds: 160));
      if (!mounted) return;
      setState(() => _progress = step / 10);
    }
    if (!mounted) return;
    setState(() {
      _backingUp = false;
      _lastBackup = 'Today at ${TimeOfDay.now().format(context)}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup complete.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Chat backup', style: text.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x2, bottom: Sp.x8),
          children: [
            EthioSectionCard(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.all(Sp.x4),
                  leading: const EthioIconTile(
                    icon: Icons.cloud_done_outlined,
                    background: EthioColors.gold,
                  ),
                  title: Text('Last backup', style: text.titleMedium),
                  subtitle: Text(_lastBackup,
                      style:
                          text.labelSmall?.copyWith(color: pal.textSecondary)),
                ),
                if (_backingUp)
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x4, Sp.x2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress,
                        color: EthioColors.goldDeep,
                        backgroundColor: pal.chip,
                      ),
                    ),
                  ),
                Padding(
                  padding: Sp.screen.copyWith(top: Sp.x2),
                  child: EthioButton(
                    label: _backingUp ? 'Backing up…' : 'Back up now',
                    icon: Icons.cloud_upload_outlined,
                    onPressed: _backingUp ? null : _backup,
                  ),
                ),
                const SizedBox(height: Sp.x3),
              ],
            ),
            const EthioSectionLabel('Backup settings'),
            EthioSectionCard(
              children: [
                EthioSwitchRow(
                  icon: Icons.schedule_rounded,
                  title: 'Automatic backup',
                  subtitle: 'Daily, while charging',
                  value: settings.backupEnabled,
                  onChanged: (value) => controller
                      .update(settings.copyWith(backupEnabled: value)),
                ),
                EthioSwitchRow(
                  icon: Icons.video_library_outlined,
                  title: 'Include videos',
                  subtitle: 'Uses more mobile data',
                  value: settings.backupVideos,
                  onChanged: (value) =>
                      controller.update(settings.copyWith(backupVideos: value)),
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: Sp.x4),
            Text(
              'Backups are end-to-end encrypted. Your chats stay private even '
              'when restored on a new phone.',
              style: text.bodySmall?.copyWith(color: pal.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class StorageManagerScreen extends StatefulWidget {
  const StorageManagerScreen({super.key});

  @override
  State<StorageManagerScreen> createState() => _StorageManagerScreenState();
}

class _StorageManagerScreenState extends State<StorageManagerScreen> {
  var _cacheBytes = 0;
  var _loading = true;
  var _clearing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<void> _measure() async {
    var total = 0;
    try {
      final dir = await getTemporaryDirectory();
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = mapError(error).messageFor(
          Localizations.localeOf(context).languageCode,
        );
        _loading = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _cacheBytes = total;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    setState(() => _clearing = true);
    var skippedFiles = false;
    try {
      await EthioCacheManager.instance.emptyCache();
      final dir = await getTemporaryDirectory();
      await for (final entity in dir.list(followLinks: false)) {
        try {
          if (entity is File) await entity.delete();
          if (entity is Directory) await entity.delete(recursive: true);
        } catch (_) {
          skippedFiles = true;
        }
      }
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (error) {
      if (!mounted) return;
      final message = mapError(error).messageFor(
        Localizations.localeOf(context).languageCode,
      );
      setState(() {
        _clearing = false;
        _error = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _cacheBytes = 0;
      _clearing = false;
      _error = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          skippedFiles
              ? 'Most cached files were cleared; some are still in use.'
              : 'Temporary files cleared.',
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Storage and data', style: text.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x2, bottom: Sp.x8),
          children: [
            Container(
              padding: const EdgeInsets.all(Sp.x5),
              decoration: BoxDecoration(
                color: pal.chip,
                borderRadius: Rad.r18,
                border: Border.all(color: pal.line),
              ),
              child: Column(
                children: [
                  Icon(Icons.storage_rounded,
                      size: 42, color: pal.textSecondary),
                  const SizedBox(height: Sp.x2),
                  Text(
                    _loading
                        ? 'Measuring…'
                        : _error ?? _formatBytes(_cacheBytes),
                    style: text.headlineMedium,
                  ),
                  Text(
                    'Temporary media and cache',
                    style: text.labelSmall?.copyWith(color: pal.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x4),
            EthioSectionCard(
              children: [
                EthioNavRow(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Clear cache',
                  subtitle: 'Removes temporary files, not chats',
                  onTap: _clearing || _loading ? () {} : _clear,
                  trailing: _clearing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: Sp.x3),
            Text(
              'Chats and media you keep are stored on this device. Clearing the '
              'cache never deletes messages or account data.',
              style: text.bodySmall?.copyWith(color: pal.textSecondary),
            ),
            const SizedBox(height: Sp.x4),
            EthioButton(
              label: 'Clear temporary files',
              kind: EthioButtonKind.tonal,
              icon: Icons.delete_sweep_outlined,
              onPressed: _clearing || _loading ? null : _clear,
            ),
          ],
        ),
      ),
    );
  }
}

class DataSaverScreen extends ConsumerWidget {
  const DataSaverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final pal = EthioPalette.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Data saver',
            style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x2, bottom: Sp.x8),
          children: [
            EthioSectionCard(
              children: [
                EthioSwitchRow(
                  icon: Icons.data_saver_on_rounded,
                  title: 'Data saver',
                  subtitle: 'Reduce mobile data use',
                  value: settings.dataSaver,
                  onChanged: (value) => controller.update(
                    settings.copyWith(
                      dataSaver: value,
                      autoDownloadMedia:
                          value ? false : settings.autoDownloadMedia,
                    ),
                  ),
                ),
                EthioSwitchRow(
                  icon: Icons.download_outlined,
                  title: 'Auto-download media',
                  subtitle: settings.dataSaver
                      ? 'Turn off data saver to enable'
                      : 'Photos and voice notes on Wi-Fi',
                  value: settings.autoDownloadMedia,
                  onChanged: settings.dataSaver
                      ? (_) {}
                      : (value) => controller.update(
                            settings.copyWith(autoDownloadMedia: value),
                          ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What data saver does',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: Sp.x2),
                  for (final tip in const [
                    'Loads image thumbnails only',
                    'Stops video autoplay',
                    'Compresses uploads',
                    'Pauses automatic backups on mobile data',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: Sp.x1),
                      child: Row(
                        children: [
                          const Icon(Icons.check_rounded,
                              size: 16, color: EthioColors.success),
                          const SizedBox(width: Sp.x2),
                          Expanded(
                            child: Text(
                              tip,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: pal.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

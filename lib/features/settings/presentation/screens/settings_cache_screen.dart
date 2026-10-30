import 'package:flutter/material.dart';

import '../../../../core/cache/cache_manager_service.dart';
import '../../../../core/design/design.dart';

class CacheSettingsScreen extends StatefulWidget {
  const CacheSettingsScreen({super.key});

  @override
  State<CacheSettingsScreen> createState() => _CacheSettingsScreenState();
}

class _CacheSettingsScreenState extends State<CacheSettingsScreen> {
  String _cacheSize = 'Calculating...';
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  Future<void> _loadSize() async {
    final size = await CacheManagerService.instance.getCacheSize();
    if (mounted) {
      setState(
          () => _cacheSize = CacheManagerService.instance.formatSize(size));
    }
  }

  Future<void> _clearCache() async {
    setState(() => _clearing = true);
    await CacheManagerService.instance.clearAll();
    await _loadSize();
    if (mounted) {
      setState(() => _clearing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Storage & Cache'),
      ),
      body: ListView(
        padding: Sp.screen,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: Rad.r18,
              border: Border.all(color: pal.line),
            ),
            padding: Sp.screen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cache',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: Sp.x2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current size',
                      style: TextStyle(color: pal.textSecondary),
                    ),
                    Text(_cacheSize),
                  ],
                ),
                const SizedBox(height: Sp.x4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _clearing ? null : _clearCache,
                    child: _clearing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Clear cache'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.x4),
          Text(
            'Clearing cache removes cached images and temporary files. Your messages and chats remain safe.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: pal.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

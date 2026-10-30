import 'dart:io';

import 'package:path_provider/path_provider.dart';

class CacheManagerService {
  CacheManagerService._();
  static final CacheManagerService instance = CacheManagerService._();

  Future<int> getCacheSize() async {
    int total = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        total += await _calculateSize(tempDir);
      }
      final cacheDir = await getApplicationCacheDirectory();
      if (cacheDir.existsSync()) {
        total += await _calculateSize(cacheDir);
      }
    } catch (_) {}
    return total;
  }

  Future<int> _calculateSize(FileSystemEntity entity) async {
    if (entity is File) {
      try {
        return await entity.length();
      } catch (_) {
        return 0;
      }
    }
    if (entity is Directory) {
      int sum = 0;
      try {
        await for (final child in entity.list(recursive: true)) {
          sum += await _calculateSize(child);
        }
      } catch (_) {}
      return sum;
    }
    return 0;
  }

  String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> clearAll() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        await _deleteDirectory(tempDir);
      }
      final cacheDir = await getApplicationCacheDirectory();
      if (cacheDir.existsSync()) {
        await _deleteDirectory(cacheDir);
      }
    } catch (_) {}
  }

  Future<void> _deleteDirectory(Directory dir) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File) {
          try {
            await entity.delete();
          } catch (_) {}
        } else if (entity is Directory) {
          await _deleteDirectory(entity);
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}

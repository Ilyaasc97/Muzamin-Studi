// lib/services/audio_cache_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Result of a cache cleaning operation.
class CacheCleanResult {
  final int bytesFreed;
  final int filesDeleted;

  const CacheCleanResult({
    required this.bytesFreed,
    required this.filesDeleted,
  });
}

/// Service to manage local caching of downloaded cloud audio files.
class AudioCacheService {
  AudioCacheService._();
  static final AudioCacheService instance = AudioCacheService._();

  static const String cacheDirName = 'muzamin_cache';

  /// Returns the cache directory, creating it if it doesn't exist.
  Future<Directory> getCacheDirectory() async {
    final Directory tempDir = await getTemporaryDirectory();
    final Directory dir = Directory(p.join(tempDir.path, cacheDirName));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Calculates total size of cached audio files in bytes.
  Future<int> getCacheSizeBytes() async {
    try {
      final dir = await getCacheDirectory();
      if (!dir.existsSync()) return 0;

      int totalBytes = 0;
      await for (final FileSystemEntity entity in dir.list(followLinks: false)) {
        if (entity is File) {
          try {
            totalBytes += await entity.length();
          } catch (e) {
            debugPrint('AudioCacheService: error reading length for ${entity.path}: $e');
          }
        }
      }
      return totalBytes;
    } catch (e) {
      debugPrint('AudioCacheService: error getting cache size: $e');
      return 0;
    }
  }

  /// Returns total count of cached audio files.
  Future<int> getCacheFileCount() async {
    try {
      final dir = await getCacheDirectory();
      if (!dir.existsSync()) return 0;

      int count = 0;
      await for (final FileSystemEntity entity in dir.list(followLinks: false)) {
        if (entity is File) {
          count++;
        }
      }
      return count;
    } catch (e) {
      debugPrint('AudioCacheService: error getting file count: $e');
      return 0;
    }
  }

  /// Clears all cached files, optionally preserving [activeFilePath] (currently loaded/playing audio).
  Future<CacheCleanResult> clearCache({String? activeFilePath}) async {
    int bytesFreed = 0;
    int filesDeleted = 0;

    try {
      final dir = await getCacheDirectory();
      if (!dir.existsSync()) {
        return const CacheCleanResult(bytesFreed: 0, filesDeleted: 0);
      }

      await for (final FileSystemEntity entity in dir.list(followLinks: false)) {
        if (entity is File) {
          if (activeFilePath != null && p.canonicalize(entity.path) == p.canonicalize(activeFilePath)) {
            continue;
          }
          try {
            final int size = await entity.length();
            await entity.delete();
            bytesFreed += size;
            filesDeleted++;
          } catch (e) {
            debugPrint('AudioCacheService: error deleting cached file ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('AudioCacheService: error clearing cache: $e');
    }

    return CacheCleanResult(bytesFreed: bytesFreed, filesDeleted: filesDeleted);
  }

  /// Automatically purges cached files older than [maxAge] (defaults to 7 days).
  /// Safely ignores the currently active audio file if [activeFilePath] is provided.
  Future<CacheCleanResult> autoCleanOldCache({
    Duration maxAge = const Duration(days: 7),
    String? activeFilePath,
  }) async {
    int bytesFreed = 0;
    int filesDeleted = 0;

    try {
      final dir = await getCacheDirectory();
      if (!dir.existsSync()) {
        return const CacheCleanResult(bytesFreed: 0, filesDeleted: 0);
      }

      final DateTime threshold = DateTime.now().subtract(maxAge);

      await for (final FileSystemEntity entity in dir.list(followLinks: false)) {
        if (entity is File) {
          if (activeFilePath != null && p.canonicalize(entity.path) == p.canonicalize(activeFilePath)) {
            continue;
          }
          try {
            final FileStat stat = await entity.stat();
            if (stat.modified.isBefore(threshold)) {
              final int size = stat.size;
              await entity.delete();
              bytesFreed += size;
              filesDeleted++;
              debugPrint('AudioCacheService: Auto-purged old cache file: ${entity.path}');
            }
          } catch (e) {
            debugPrint('AudioCacheService: error inspecting/purging ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('AudioCacheService: error during autoCleanOldCache: $e');
    }

    return CacheCleanResult(bytesFreed: bytesFreed, filesDeleted: filesDeleted);
  }

  /// Utility to format bytes into readable KB/MB/GB format.
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tafsir_timing_tool/services/audio_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioCacheService - formatBytes', () {
    test('تنسيق الأحجام المختلفة بشكل صحيح', () {
      expect(AudioCacheService.formatBytes(0), '0 B');
      expect(AudioCacheService.formatBytes(-50), '0 B');
      expect(AudioCacheService.formatBytes(500), '500 B');
      expect(AudioCacheService.formatBytes(1024), '1.0 KB');
      expect(AudioCacheService.formatBytes(1536), '1.5 KB');
      expect(AudioCacheService.formatBytes(1024 * 1024), '1.0 MB');
      expect(AudioCacheService.formatBytes(25 * 1024 * 1024), '25.0 MB');
      expect(AudioCacheService.formatBytes(1024 * 1024 * 1024), '1.00 GB');
    });
  });

  group('AudioCacheService - Cache management operations', () {
    late Directory tempTestDir;
    final service = AudioCacheService.instance;
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');

    setUp(() async {
      tempTestDir = await Directory.systemTemp.createTemp('muzamin_test_cache_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getTemporaryDirectory') {
          return tempTestDir.path;
        }
        return null;
      });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (tempTestDir.existsSync()) {
        try {
          tempTestDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('getCacheDirectory يُنشئ المجلد إذا لم يكن موجوداً', () async {
      final dir = await service.getCacheDirectory();
      expect(dir.existsSync(), isTrue);
      expect(p.basename(dir.path), AudioCacheService.cacheDirName);
    });

    test('clearCache ينظف الملفات ويعيد الحجم المحذوف', () async {
      final dir = await service.getCacheDirectory();
      final dummyFile = File(p.join(dir.path, 'test_dummy_audio.mp3'));
      await dummyFile.writeAsBytes(List.filled(2048, 42));

      expect(dummyFile.existsSync(), isTrue);
      final sizeBefore = await service.getCacheSizeBytes();
      expect(sizeBefore, greaterThanOrEqualTo(2048));
      final countBefore = await service.getCacheFileCount();
      expect(countBefore, greaterThanOrEqualTo(1));

      final cleanResult = await service.clearCache();
      expect(cleanResult.filesDeleted, greaterThanOrEqualTo(1));
      expect(cleanResult.bytesFreed, greaterThanOrEqualTo(2048));
      expect(dummyFile.existsSync(), isFalse);
    });

    test('autoCleanOldCache يحذف فقط الملفات الأقدم من المدة المحددة', () async {
      final dir = await service.getCacheDirectory();
      final oldFile = File(p.join(dir.path, 'old_audio.mp3'));
      await oldFile.writeAsBytes(List.filled(1000, 1));
      // Set last modified date to 10 days ago
      await oldFile.setLastModified(DateTime.now().subtract(const Duration(days: 10)));

      final newFile = File(p.join(dir.path, 'new_audio.mp3'));
      await newFile.writeAsBytes(List.filled(1000, 2));

      final result = await service.autoCleanOldCache(maxAge: const Duration(days: 7));
      expect(result.filesDeleted, 1);
      expect(oldFile.existsSync(), isFalse);
      expect(newFile.existsSync(), isTrue);
    });
  });
}

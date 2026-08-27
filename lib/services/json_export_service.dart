import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/app_logger.dart';
import '../models/timing_entry.dart';

class ExportResult {
  const ExportResult({
    required this.path,
    required this.segmentCount,
    required this.verseCount,
  });

  final String path;
  final int segmentCount;
  final int verseCount;
}

class JsonExportService {
  static const int _schemaVersion = 2;

  Future<ExportResult?> export({
    required String lessonId,
    required String audioUrl,
    required String? sourceFilePath,
    required List<TimingEntry> entries,
    bool includeText = false,
  }) async {
    if (entries.isEmpty) {
      throw const ExportException('لا توجد توقيتات مسجلة للتصدير.');
    }

    if (lessonId.trim().isEmpty) {
      throw const ExportException('معرّف الدرس مطلوب ولا يمكن أن يكون فارغاً.');
    }

    // التحقق من صحة جميع الإدخالات
    for (final entry in entries) {
      if (!entry.isValid) {
        throw ExportException(
          'المقطع ${entry.effectiveLabel} غير صالح: '
          'البداية (${entry.startMs}ms) ≥ النهاية (${entry.endMs}ms)',
        );
      }
    }

    final DateTime now = DateTime.now();

    // إحصاء العناصر حسب النوع
    final Map<String, int> countsByType = <String, int>{};
    for (final type in SegmentType.values) {
      countsByType[type.name] = 0;
    }
    for (final entry in entries) {
      countsByType[entry.type.name] =
          (countsByType[entry.type.name] ?? 0) + 1;
    }

    final pages = entries.map((e) => e.page).whereType<int>().toList();
    final Map<String, dynamic>? pageRange = pages.isNotEmpty
        ? <String, dynamic>{
            'from': pages.reduce(math.min),
            'to': pages.reduce(math.max),
            'fromJuz': TimingEntry.getJuzForPage(pages.reduce(math.min)),
            'toJuz': TimingEntry.getJuzForPage(pages.reduce(math.max)),
          }
        : null;

    final Map<String, dynamic> payload = <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'lessonId': lessonId.trim(),
      'audioUrl': audioUrl.trim(),
      'sourceFile': sourceFilePath == null ? null : p.basename(sourceFilePath),
      'exportedAt': now.toUtc().toIso8601String(),
      'totalSegments': entries.length,
      'totalDurationMs': entries.isEmpty
          ? 0
          : entries.last.endMs - entries.first.startMs,
      if (pageRange != null) 'pageRange': pageRange,
      'countsByType': countsByType,
      'segments': entries.map((TimingEntry e) => e.toJson(includeText: includeText)).toList(),
    };

    try {
      final String jsonText =
          const JsonEncoder.withIndent('  ').convert(payload);
      final String suggestedName =
          'sync_${_safeFileName(lessonId.trim().isEmpty ? 'lesson' : lessonId.trim())}'
          '_${now.millisecondsSinceEpoch}.json';

      final String? targetPath = await _resolveTargetPath(suggestedName);
      if (targetPath == null) return null;

      try {
        await File(targetPath).writeAsString('$jsonText\n', flush: true);
        AppLogger.instance.info('تم تصدير الملف بنجاح إلى: $targetPath');
      } on FileSystemException catch (e, stack) {
        AppLogger.instance.error('فشل كتابة ملف التصدير', e, stack);
        throw ExportException('خطأ في الكتابة إلى الملف: ${e.message}');
      }

      return ExportResult(
        path: targetPath,
        segmentCount: entries.length,
        verseCount: countsByType[SegmentType.quran.name] ?? 0,
      );
    } catch (error, stack) {
      if (error is ExportException) rethrow;
      AppLogger.instance.error('خطأ غير متوقع في التصدير', error, stack);
      throw ExportException('خطأ غير متوقع في التصدير: $error');
    }
  }

  Future<String?> _resolveTargetPath(String suggestedName) async {
    final bool isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);

    if (isDesktop) {
      try {
        final dynamic location = await getSaveLocation(
          suggestedName: suggestedName,
          acceptedTypeGroups: const <XTypeGroup>[
            XTypeGroup(label: 'JSON', extensions: <String>['json']),
          ],
        );
        if (location != null) {
          final String path = location.path as String;
          return path.endsWith('.json') ? path : '$path.json';
        }
        return null;
      } catch (_) {
        return _defaultPath(suggestedName);
      }
    }
    return _defaultPath(suggestedName);
  }

  Future<String> _defaultPath(String fileName) async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory downloads =
        Directory(p.join(docs.parent.path, 'Downloads'));
    final Directory target = await downloads.exists() ? downloads : docs;
    return p.join(target.path, fileName);
  }

  String _safeFileName(String raw) =>
      raw.replaceAll(RegExp(r'[^\w\u0600-\u06FF-]+'), '_');
}

class ExportException implements Exception {
  const ExportException(this.message);
  final String message;

  @override
  String toString() => message;
}

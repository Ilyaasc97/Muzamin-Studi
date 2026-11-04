import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/app_logger.dart';
import '../models/timing_entry.dart';
import 'json_export_service.dart';
import 'quran_api_service.dart';

enum ExportFormat {
  json,
  dart,
  flutterPlayer,
  vtt,
  srt,
  audacity,
  csv,
  manifest,
}

class MultiFormatExportService {
  MultiFormatExportService._();
  static final MultiFormatExportService instance =
      MultiFormatExportService._();

  /// فحص ما إذا كان النص يحتوي على محارف PUA (Private Use Area)
  /// الخاصة بخطوط مصحف المدينة والتي تظهر كمربعات فارغة في البرامج العادية مثل Audacity و Excel
  static bool containsPuaGlyphs(String text) {
    for (final rune in text.runes) {
      if ((rune >= 0xE000 && rune <= 0xF8FF) ||
          (rune >= 0xFB50 && rune <= 0xFDFF) ||
          (rune >= 0xFE70 && rune <= 0xFEFC) ||
          (rune >= 0xF0000 && rune <= 0x10FFFD)) {
        return true;
      }
    }
    return false;
  }

  String generateWebVtt({
    required String lessonId,
    required List<TimingEntry> entries,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('WEBVTT - Muzamin Audio Sync: $lessonId\n');

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final start = _formatVttTimestamp(entry.startMs);
      final end = _formatVttTimestamp(entry.endMs);
      final label = entry.effectiveLabel;
      final arabic = entry.textArabic != null && entry.textArabic!.isNotEmpty
          ? '\n${entry.textArabic}'
          : '';

      buffer.writeln('${i + 1}');
      buffer.writeln('$start --> $end');
      buffer.writeln('[${entry.type.name} #${entry.verseNumber}] $label$arabic\n');
    }

    return buffer.toString();
  }

  String generateSrt({
    required List<TimingEntry> entries,
  }) {
    final buffer = StringBuffer();

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final start = _formatSrtTimestamp(entry.startMs);
      final end = _formatSrtTimestamp(entry.endMs);
      final label = entry.effectiveLabel;
      final arabic = entry.textArabic != null && entry.textArabic!.isNotEmpty
          ? '\n${entry.textArabic}'
          : '';

      buffer.writeln('${i + 1}');
      buffer.writeln('$start --> $end');
      buffer.writeln('[${entry.type.name} #${entry.verseNumber}] $label$arabic\n');
    }

    return buffer.toString();
  }

  String generateAudacityLabels({
    required List<TimingEntry> entries,
  }) {
    final lines = <String>[];

    for (final entry in entries) {
      final double startSec = entry.startMs / 1000.0;
      final double endSec = (entry.endMs >= entry.startMs ? entry.endMs : entry.startMs) / 1000.0;

      // استخراج تسمية صريحة مقروءة بوضوح داخل Audacity
      String labelText = '';
      if (entry.label != null && entry.label!.trim().isNotEmpty) {
        labelText = entry.label!.trim();
      } else if (entry.type == SegmentType.quran) {
        final surah = QuranApiService.instance.getSurahNameForAyah(
          page: entry.page,
          ayah: entry.verseNumber,
        );
        labelText = surah != null
            ? '$surah (${entry.verseNumber})'
            : entry.effectiveLabel;
      } else {
        labelText = entry.effectiveLabel;
      }

      final labelParts = <String>[];
      labelParts.add('[${entry.type.name} #${entry.verseNumber}]');
      if (labelText.isNotEmpty) {
        labelParts.add(labelText.replaceAll(RegExp(r'[\t\r\n]+'), ' ').trim());
      }

      // إضافة النص العربي فقط إذا كان نصاً عربياً حقيقياً مقروءاً وليس رموز PUA خاصة بخط المصحف
      if (entry.textArabic != null && entry.textArabic!.trim().isNotEmpty) {
        final cleanArabic = entry.textArabic!.replaceAll(RegExp(r'[\t\r\n]+'), ' ').trim();
        if (!containsPuaGlyphs(cleanArabic)) {
          labelParts.add(cleanArabic);
        }
      }

      // إزالة أي tab أو فواصل أسطر داخل التسمية لمنع أخطاء التقسيم في Audacity
      final cleanLabel = labelParts
          .join(' - ')
          .replaceAll('\t', ' ')
          .replaceAll(RegExp(r'[\r\n]+'), ' ')
          .trim();

      lines.add(
        '${startSec.toStringAsFixed(6)}\t${endSec.toStringAsFixed(6)}\t$cleanLabel',
      );
    }

    // ربط الأسطر بدون سطر فارغ في النهاية لمنع رسالة Audacity: "One or more saved labels could not be read"
    return lines.join('\r\n');
  }

  String generateCsv({
    required String lessonId,
    required List<TimingEntry> entries,
  }) {
    final buffer = StringBuffer();
    // Prepend UTF-8 BOM so Microsoft Excel displays Arabic text properly without mojibake
    buffer.write('\uFEFF');

    buffer.writeln(
      '#,"Type","Surah/Label","Page","Juz","Start Time","End Time","Duration","Start (ms)","End (ms)","Arabic Text"',
    );

    for (final entry in entries) {
      final id = entry.verseNumber;
      final type = _escapeCsv(entry.type.name);

      String labelText = entry.label ?? '';
      if (labelText.isEmpty && entry.type == SegmentType.quran) {
        final surah = QuranApiService.instance.getSurahNameForAyah(
          page: entry.page,
          ayah: entry.verseNumber,
        );
        labelText = surah != null ? '$surah: ${entry.verseNumber}' : entry.effectiveLabel;
      } else if (labelText.isEmpty) {
        labelText = entry.effectiveLabel;
      }

      final label = _escapeCsv(labelText);
      final page = entry.page?.toString() ?? '';
      final juz = entry.juz?.toString() ?? '';
      final startFormatted = _escapeCsv(TimingEntry.formatTime(entry.startMs));
      final endFormatted = _escapeCsv(TimingEntry.formatTime(entry.endMs));
      final durFormatted = _escapeCsv(TimingEntry.formatTime(entry.durationMs));
      final startMs = entry.startMs;
      final endMs = entry.endMs;

      // إذا كان النص العربي الأصلي يحتوي على رموز PUA خطية للمصحف، نستبدله بالتسمية المقروءة لمنع المربعات في إكسل
      final rawArabic = entry.textArabic ?? '';
      final arabicOutput = (rawArabic.isNotEmpty && containsPuaGlyphs(rawArabic))
          ? labelText
          : rawArabic;
      final arabicText = _escapeCsv(arabicOutput);

      buffer.writeln(
        '$id,$type,$label,$page,$juz,$startFormatted,$endFormatted,$durFormatted,$startMs,$endMs,$arabicText',
      );
    }

    return buffer.toString();
  }

  static String _escapeCsv(String field) {
    if (field.contains('"') ||
        field.contains(',') ||
        field.contains('\n') ||
        field.contains('\r')) {
      final escaped = field.replaceAll('"', '""');
      return '"$escaped"';
    }
    return '"$field"';
  }

  String generateDartSeed({
    required String lessonId,
    required String audioUrl,
    required List<TimingEntry> entries,
  }) {
    final buffer = StringBuffer();
    final safeClassName = _toPascalCase(lessonId.isEmpty ? 'Lesson' : lessonId);

    buffer.writeln('// Generated by Muzamin Studio - ${DateTime.now().toUtc().toIso8601String()}');
    buffer.writeln('// Production-ready data seed and model for Flutter / Isar / SQLite / Supabase\n');

    buffer.writeln('/// Model class representing a synchronized timing segment');
    buffer.writeln('class VerseTimestampModel {');
    buffer.writeln('  final int id;');
    buffer.writeln('  final int number;');
    buffer.writeln('  final String type;');
    buffer.writeln('  final int? page;');
    buffer.writeln('  final int? juz;');
    buffer.writeln('  final int startMs;');
    buffer.writeln('  final int endMs;');
    buffer.writeln('  final int durationMs;');
    buffer.writeln('  final String? label;');
    buffer.writeln('  final String? textArabic;\n');
    buffer.writeln('  const VerseTimestampModel({');
    buffer.writeln('    required this.id,');
    buffer.writeln('    required this.number,');
    buffer.writeln('    required this.type,');
    buffer.writeln('    this.page,');
    buffer.writeln('    this.juz,');
    buffer.writeln('    required this.startMs,');
    buffer.writeln('    required this.endMs,');
    buffer.writeln('    required this.durationMs,');
    buffer.writeln('    this.label,');
    buffer.writeln('    this.textArabic,');
    buffer.writeln('  });\n');
    buffer.writeln('  factory VerseTimestampModel.fromJson(Map<String, dynamic> json) {');
    buffer.writeln('    return VerseTimestampModel(');
    buffer.writeln("      id: (json['id'] as num?)?.toInt() ?? 0,");
    buffer.writeln("      number: (json['number'] as num?)?.toInt() ?? (json['verseNumber'] as num?)?.toInt() ?? 0,");
    buffer.writeln("      type: json['type'] as String? ?? 'quran',");
    buffer.writeln("      page: (json['page'] as num?)?.toInt(),");
    buffer.writeln("      juz: (json['juz'] as num?)?.toInt(),");
    buffer.writeln("      startMs: (json['startMs'] as num?)?.toInt() ?? 0,");
    buffer.writeln("      endMs: (json['endMs'] as num?)?.toInt() ?? 0,");
    buffer.writeln("      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,");
    buffer.writeln("      label: json['label'] as String?,");
    buffer.writeln("      textArabic: json['textArabic'] as String?,");
    buffer.writeln('    );');
    buffer.writeln('  }\n');
    buffer.writeln('  Map<String, dynamic> toJson() {');
    buffer.writeln('    return <String, dynamic>{');
    buffer.writeln("      'id': id,");
    buffer.writeln("      'number': number,");
    buffer.writeln("      'type': type,");
    buffer.writeln("      if (page != null) 'page': page,");
    buffer.writeln("      if (juz != null) 'juz': juz,");
    buffer.writeln("      'startMs': startMs,");
    buffer.writeln("      'endMs': endMs,");
    buffer.writeln("      'durationMs': durationMs,");
    buffer.writeln("      if (label != null) 'label': label,");
    buffer.writeln("      if (textArabic != null) 'textArabic': textArabic,");
    buffer.writeln('    };');
    buffer.writeln('  }');
    buffer.writeln('}\n');

    buffer.writeln('class ${safeClassName}Seed {');
    buffer.writeln("  static const String lessonId = '$lessonId';");
    buffer.writeln("  static const String audioUrl = '$audioUrl';");
    buffer.writeln('  static const int totalSegments = ${entries.length};');
    buffer.writeln("  static const String timingMode = 'absolute'; // Milliseconds from start of audio");
    buffer.writeln('  static List<VerseTimestampModel> get items =>');
    buffer.writeln('      segments.map(VerseTimestampModel.fromJson).toList(growable: false);\n');
    buffer.writeln('  static const List<Map<String, dynamic>> segments = <Map<String, dynamic>>[');

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      buffer.writeln('    <String, dynamic>{');
      buffer.writeln("      'id': ${i + 1},");
      buffer.writeln("      'number': ${entry.verseNumber},");
      buffer.writeln("      'type': '${entry.type.name}',");
      if (entry.page != null) {
        buffer.writeln("      'page': ${entry.page},");
        buffer.writeln("      'juz': ${entry.juz},");
      }
      buffer.writeln("      'startMs': ${entry.startMs},");
      buffer.writeln("      'endMs': ${entry.endMs},");
      buffer.writeln("      'durationMs': ${entry.durationMs},");
      if (entry.label != null) {
        buffer.writeln("      'label': '${_escapeDart(entry.label!)}',");
      }
      if (entry.textArabic != null) {
        buffer.writeln("      'textArabic': '${_escapeDart(entry.textArabic!)}',");
      }
      buffer.writeln('    },');
    }

    buffer.writeln('  ];');
    buffer.writeln('}\n');

    return buffer.toString();
  }

  String generateManifest({
    required String lessonId,
    required String audioUrl,
    String? sourceFilePath,
    required List<TimingEntry> entries,
  }) {
    final now = DateTime.now();
    final countsByType = <String, int>{};
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

    final totalDurationMs = entries.isEmpty
        ? 0
        : entries.last.endMs - entries.first.startMs;

    final cleanLesson = _safeFileName(lessonId.trim().isEmpty ? 'lesson' : lessonId.trim());

    final manifestData = <String, dynamic>{
      'manifestVersion': 1,
      'exportedAt': now.toUtc().toIso8601String(),
      'lesson': <String, dynamic>{
        'lessonId': lessonId.trim(),
        'audioUrl': audioUrl.trim(),
        'sourceFile': sourceFilePath == null ? null : p.basename(sourceFilePath),
        'dataFile': '$cleanLesson.json',
        'totalSegments': entries.length,
        'totalDurationMs': totalDurationMs,
        'timingMode': 'absolute',
        if (pageRange != null) 'pageRange': pageRange,
        'countsByType': countsByType,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(manifestData);
  }

  String generateFlutterPlayerWidget({
    required String lessonId,
    required String audioUrl,
    required List<TimingEntry> entries,
  }) {
    final safeClassName = _toPascalCase(lessonId.isEmpty ? 'Lesson' : lessonId);
    final buffer = StringBuffer();

    buffer.writeln('// =========================================================================');
    buffer.writeln('// Generated by Muzamin Studio - ${DateTime.now().toUtc().toIso8601String()}');
    buffer.writeln('// Ready-to-use Synchronized Audio Player Widget for Flutter Apps');
    buffer.writeln('// Dependencies: just_audio: ^0.10.4');
    buffer.writeln('// =========================================================================\n');
    buffer.writeln("import 'dart:ui' as ui;");
    buffer.writeln("import 'package:flutter/material.dart';");
    buffer.writeln("import 'package:just_audio/just_audio.dart';\n");
    buffer.writeln('class ${safeClassName}SyncPlayer extends StatefulWidget {');
    buffer.writeln('  const ${safeClassName}SyncPlayer({');
    buffer.writeln('    super.key,');
    buffer.writeln("    this.audioSource = '$audioUrl',");
    buffer.writeln('  });\n');
    buffer.writeln('  final String audioSource;\n');
    buffer.writeln('  @override');
    buffer.writeln('  State<${safeClassName}SyncPlayer> createState() => _${safeClassName}SyncPlayerState();');
    buffer.writeln('}\n');
    buffer.writeln('class _${safeClassName}SyncPlayerState extends State<${safeClassName}SyncPlayer> {');
    buffer.writeln('  late final AudioPlayer _player;');
    buffer.writeln('  final ScrollController _scrollController = ScrollController();');
    buffer.writeln('  int? _activeSegmentIndex;\n');
    buffer.writeln('  static const List<Map<String, dynamic>> _segments = [');

    for (final entry in entries) {
      buffer.writeln('    {');
      buffer.writeln("      'number': ${entry.verseNumber},");
      buffer.writeln("      'type': '${entry.type.name}',");
      if (entry.page != null) buffer.writeln("      'page': ${entry.page},");
      buffer.writeln("      'startMs': ${entry.startMs},");
      buffer.writeln("      'endMs': ${entry.endMs},");
      if (entry.label != null) buffer.writeln("      'label': '${_escapeDart(entry.label!)}',");
      if (entry.textArabic != null) buffer.writeln("      'textArabic': '${_escapeDart(entry.textArabic!)}',");
      buffer.writeln('    },');
    }

    buffer.writeln('  ];\n');
    buffer.writeln('''  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      if (widget.audioSource.startsWith('http')) {
        await _player.setUrl(widget.audioSource);
      } else {
        await _player.setFilePath(widget.audioSource);
      }
    } catch (e) {
      debugPrint('Error loading audio: \$e');
    }

    _player.positionStream.listen((pos) {
      final posMs = pos.inMilliseconds;
      final idx = _segments.indexWhere((s) => posMs >= (s['startMs'] as int) && posMs <= (s['endMs'] as int));
      if (idx != -1 && idx != _activeSegmentIndex) {
        setState(() => _activeSegmentIndex = idx);
        _scrollToIndex(idx);
      }
    });
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    const itemHeight = 72.0;
    final target = (index * itemHeight) - 100;
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('$lessonId - Sync Player')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _segments.length,
              itemBuilder: (context, index) {
                final seg = _segments[index];
                final isActive = index == _activeSegmentIndex;
                final textArabic = seg['textArabic'] as String?;
                final label = seg['label'] as String?;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5) : theme.cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive ? theme.colorScheme.primary : theme.dividerColor,
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                      foregroundColor: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                      child: Text('\${seg['number']}'),
                    ),
                    title: textArabic != null
                        ? Text(
                            textArabic,
                            textDirection: ui.TextDirection.rtl,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              color: isActive ? theme.colorScheme.primary : null,
                            ),
                          )
                        : Text(label ?? ''),
                    subtitle: Text('\${(seg['startMs'] / 1000).toStringAsFixed(1)}s → \${(seg['endMs'] / 1000).toStringAsFixed(1)}s'),
                    onTap: () => _player.seek(Duration(milliseconds: seg['startMs'] as int)),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: Row(
              children: [
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, snap) {
                    final playing = snap.data?.playing ?? false;
                    return IconButton.filled(
                      onPressed: () => playing ? _player.pause() : _player.play(),
                      icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<Duration>(
                    stream: _player.positionStream,
                    builder: (context, posSnap) {
                      final pos = posSnap.data ?? Duration.zero;
                      final dur = _player.duration ?? Duration.zero;
                      final maxVal = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
                      final val = pos.inMilliseconds.toDouble().clamp(0.0, maxVal);

                      return Slider(
                        value: val,
                        max: maxVal,
                        onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
''');

    return buffer.toString();
  }

  Future<String?> exportFormattedFile({
    required ExportFormat format,
    required String lessonId,
    required String audioUrl,
    String? sourceFilePath,
    required List<TimingEntry> entries,
  }) async {
    if (entries.isEmpty) {
      throw const ExportException('لا توجد توقيتات مسجلة للتصدير.');
    }

    if (format == ExportFormat.json) {
      final res = await JsonExportService().export(
        lessonId: lessonId,
        audioUrl: audioUrl,
        sourceFilePath: sourceFilePath,
        entries: entries,
      );
      return res?.path;
    }

    final String content;
    final String extension;
    final String label;

    switch (format) {
      case ExportFormat.vtt:
        content = generateWebVtt(lessonId: lessonId, entries: entries);
        extension = 'vtt';
        label = 'WebVTT';
        break;
      case ExportFormat.srt:
        content = generateSrt(entries: entries);
        extension = 'srt';
        label = 'SubRip SRT';
        break;
      case ExportFormat.dart:
        content = generateDartSeed(
          lessonId: lessonId,
          audioUrl: audioUrl,
          entries: entries,
        );
        extension = 'dart';
        label = 'Dart Seed Code';
        break;
      case ExportFormat.flutterPlayer:
        content = generateFlutterPlayerWidget(
          lessonId: lessonId,
          audioUrl: audioUrl,
          entries: entries,
        );
        extension = 'dart';
        label = 'Flutter Sync Player';
        break;
      case ExportFormat.audacity:
        content = generateAudacityLabels(entries: entries);
        extension = 'txt';
        label = 'Audacity Labels';
        break;
      case ExportFormat.csv:
        content = generateCsv(lessonId: lessonId, entries: entries);
        extension = 'csv';
        label = 'Excel / CSV';
        break;
      case ExportFormat.manifest:
        content = generateManifest(
          lessonId: lessonId,
          audioUrl: audioUrl,
          sourceFilePath: sourceFilePath,
          entries: entries,
        );
        extension = 'json';
        label = 'Unified Manifest';
        break;
      case ExportFormat.json:
        throw StateError('Unreachable');
    }

    final safeName = _safeFileName(lessonId.isEmpty ? 'sync' : lessonId);
    final suffix = format == ExportFormat.flutterPlayer
        ? '_player'
        : (format == ExportFormat.dart
            ? '_seed'
            : (format == ExportFormat.manifest ? '_manifest' : ''));
    final suggestedName = '$safeName$suffix.$extension';

    final targetPath = await _resolveTargetPath(suggestedName, extension, label);
    if (targetPath == null) return null;

    try {
      final String fileContent = (format == ExportFormat.audacity || format == ExportFormat.csv)
          ? content
          : (content.endsWith('\n') ? content : '$content\n');
      await File(targetPath).writeAsString(fileContent, flush: true);
      AppLogger.instance.info('تم تصدير ملف $label بنجاح إلى: $targetPath');
      return targetPath;
    } catch (e, stack) {
      AppLogger.instance.error('فشل تصدير ملف $label', e, stack);
      throw ExportException('خطأ في حفظ الملف: $e');
    }
  }

  static String _formatVttTimestamp(int totalMs) {
    final ms = (totalMs % 1000).toString().padLeft(3, '0');
    final totalSeconds = totalMs ~/ 1000;
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    final mm = ((totalSeconds ~/ 60) % 60).toString().padLeft(2, '0');
    final h = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    return '$h:$mm:$s.$ms';
  }

  static String _formatSrtTimestamp(int totalMs) {
    final ms = (totalMs % 1000).toString().padLeft(3, '0');
    final totalSeconds = totalMs ~/ 1000;
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    final mm = ((totalSeconds ~/ 60) % 60).toString().padLeft(2, '0');
    final h = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    return '$h:$mm:$s,$ms';
  }

  static String _safeFileName(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
  }

  static String _toPascalCase(String input) {
    final clean = input.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ');
    return clean
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .join();
  }

  static String _escapeDart(String text) {
    return text.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$').replaceAll('\n', r'\n');
  }

  static Future<String?> _resolveTargetPath(
    String suggestedName,
    String extension,
    String label,
  ) async {
    try {
      final location = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: [
          XTypeGroup(
            label: '$label (*.$extension)',
            extensions: [extension],
          ),
        ],
      );
      if (location != null) return location.path;
    } catch (_) {}

    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(dir.path, 'TafsirTimingTool_Exports'));
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
    return p.join(outDir.path, suggestedName);
  }
}

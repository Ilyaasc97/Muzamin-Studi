import 'package:flutter_test/flutter_test.dart';
import 'package:tafsir_timing_tool/models/timing_entry.dart';
import 'package:tafsir_timing_tool/services/multi_format_export_service.dart';

void main() {
  group('MultiFormatExportService', () {
    final service = MultiFormatExportService.instance;

    final testEntries = <TimingEntry>[
      const TimingEntry(
        id: 0,
        verseNumber: 1,
        startMs: 15230,
        endMs: 48120,
        type: SegmentType.quran,
        label: 'سورة البقرة',
        textArabic: 'الم',
      ),
      const TimingEntry(
        id: 1,
        verseNumber: 2,
        startMs: 48900,
        endMs: 90450,
        type: SegmentType.hadith,
        label: 'فضل السورة',
      ),
    ];

    test('generateWebVtt يولد ترويسة وتوقيتات صحيحة لصيغة WebVTT', () {
      final vtt = service.generateWebVtt(
        lessonId: 'baqarah_01',
        entries: testEntries,
      );

      expect(vtt, contains('WEBVTT - Muzamin Audio Sync: baqarah_01'));
      expect(vtt, contains('00:00:15.230 --> 00:00:48.120'));
      expect(vtt, contains('[quran #1]'));
      expect(vtt, contains('الم'));
      expect(vtt, contains('00:00:48.900 --> 00:01:30.450'));
    });

    test('generateSrt يولد صيغة SubRip SRT صحيحة مع فواصل التوقيت', () {
      final srt = service.generateSrt(entries: testEntries);

      expect(srt, contains('1\n00:00:15,230 --> 00:00:48,120'));
      expect(srt, contains('2\n00:00:48,900 --> 00:01:30,450'));
    });

    test('generateDartSeed يولد كود Dart جاهز للإنتاج', () {
      final dartCode = service.generateDartSeed(
        lessonId: 'baqarah_lesson_01',
        audioUrl: 'https://cdn.example.com/audio.mp3',
        entries: testEntries,
      );

      expect(dartCode, contains('class BaqarahLesson01Seed'));
      expect(dartCode, contains("static const String lessonId = 'baqarah_lesson_01';"));
      expect(dartCode, contains("static const int totalSegments = 2;"));
      expect(dartCode, contains("'type': 'quran'"));
      expect(dartCode, contains("'type': 'hadith'"));
    });
  });
}

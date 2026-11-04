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

    test('generateDartSeed يولد كود Dart مع كلاس الموديل ودوال التحويل والـ items', () {
      final dartCode = service.generateDartSeed(
        lessonId: 'baqarah_lesson_01',
        audioUrl: 'https://cdn.example.com/audio.mp3',
        entries: testEntries,
      );

      expect(dartCode, contains('class VerseTimestampModel'));
      expect(dartCode, contains('factory VerseTimestampModel.fromJson(Map<String, dynamic> json)'));
      expect(dartCode, contains('Map<String, dynamic> toJson()'));
      expect(dartCode, contains('class BaqarahLesson01Seed'));
      expect(dartCode, contains("static const String lessonId = 'baqarah_lesson_01';"));
      expect(dartCode, contains("static const int totalSegments = 2;"));
      expect(dartCode, contains("static const String timingMode = 'absolute';"));
      expect(dartCode, contains('static List<VerseTimestampModel> get items =>'));
      expect(dartCode, contains("'type': 'quran'"));
      expect(dartCode, contains("'type': 'hadith'"));
    });

    test('generateManifest يولد ملف فهرس موحد JSON بمخطط سليم وتوقيت مطلق', () {
      final manifest = service.generateManifest(
        lessonId: '007-BAQARAH77-88',
        audioUrl: 'https://cdn.example.com/audio.mp3',
        sourceFilePath: '/path/to/007-BAQARAH77-88.mp3',
        entries: testEntries,
      );

      expect(manifest, contains('"manifestVersion": 1'));
      expect(manifest, contains('"lessonId": "007-BAQARAH77-88"'));
      expect(manifest, contains('"dataFile": "007-BAQARAH77-88.json"'));
      expect(manifest, contains('"timingMode": "absolute"'));
      expect(manifest, contains('"totalSegments": 2'));
      expect(manifest, contains('"sourceFile": "007-BAQARAH77-88.mp3"'));
    });

    test('generateAudacityLabels يولد صيغة Tab-separated لقنوات تسميات Audacity', () {
      final labels = service.generateAudacityLabels(entries: testEntries);

      // StartSec \t EndSec \t Label
      expect(labels, contains('15.230000\t48.120000\t[quran #1] - سورة البقرة - الم'));
      expect(labels, contains('48.900000\t90.450000\t[hadith #2] - فضل السورة'));
    });

    test('generateCsv يولد ملف CSV متوافق مع Excel ومزود بـ UTF-8 BOM للنصوص العربية', () {
      final csv = service.generateCsv(
        lessonId: 'baqarah_01',
        entries: testEntries,
      );

      // Verify UTF-8 BOM
      expect(csv.startsWith('\uFEFF'), isTrue);
      // Verify Header
      expect(csv, contains('#,"Type","Surah/Label","Page","Juz","Start Time","End Time","Duration","Start (ms)","End (ms)","Arabic Text"'));
      // Verify data rows
      expect(csv, contains('1,"quran","سورة البقرة"'));
      expect(csv, contains('15230,48120,"الم"'));
      expect(csv, contains('2,"hadith","فضل السورة"'));
      expect(csv, contains('48900,90450'));
    });

    test('generateAudacityLabels يستبعد محارف PUA لخط المصحف لمنع ظهور المربعات في Audacity', () {
      final puaEntries = [
        const TimingEntry(
          id: 0,
          verseNumber: 77,
          startMs: 13149,
          endMs: 25532,
          type: SegmentType.quran,
          label: 'سورة البقرة: 77',
          // King Fahd Complex PUA glyphs
          textArabic: 'ﱁ ﱂ ﱃ ﱄ ﱅ ﱆ ﱇ ﱈ ﱉ ﱊ',
        ),
      ];

      expect(MultiFormatExportService.containsPuaGlyphs(puaEntries.first.textArabic!), isTrue);

      final labels = service.generateAudacityLabels(entries: puaEntries);

      // Must contain readable label
      expect(labels, contains('13.149000\t25.532000\t[quran #77] - سورة البقرة: 77'));
      // Must NOT contain PUA characters
      expect(labels, isNot(contains('ﱁ')));
      expect(labels, isNot(contains('ﱊ')));
      // Must NOT have empty trailing lines that trigger "One or more saved labels could not be read"
      final lines = labels.split('\r\n');
      expect(lines.every((line) => line.trim().isNotEmpty), isTrue);
      expect(lines.every((line) => line.split('\t').length == 3), isTrue);
    });
  });
}

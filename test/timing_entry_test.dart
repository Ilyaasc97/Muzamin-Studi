import 'package:flutter_test/flutter_test.dart';
import 'package:tafsir_timing_tool/models/timing_entry.dart';

void main() {
  group('TimingEntry', () {
    test('formatTime يعرض دقائق وثوانٍ ومللي ثانية', () {
      expect(TimingEntry.formatTime(0), '00:00.000');
      expect(TimingEntry.formatTime(65250), '01:05.250');
      expect(TimingEntry.formatTime(599999), '09:59.999');
    });

    test('formatTime يدعم الساعات للدروس الطويلة', () {
      expect(TimingEntry.formatTime(3600125), '1:00:00.125');
    });

    test('toJson يحسب المدة والبيانات تلقائياً', () {
      const TimingEntry entry = TimingEntry(
        id: 1,
        verseNumber: 3,
        startMs: 1000,
        endMs: 4500,
      );
      final json = entry.toJson();
      expect(json['verseNumber'], 3);
      expect(json['startMs'], 1000);
      expect(json['endMs'], 4500);
      expect(json['durationMs'], 3500);
      expect(json['type'], 'quran');
    });

    test('isValid يتحقق من ترتيب البداية والنهاية', () {
      const valid =
          TimingEntry(id: 1, verseNumber: 1, startMs: 100, endMs: 200);
      const invalid =
          TimingEntry(id: 2, verseNumber: 2, startMs: 300, endMs: 300);
      expect(valid.isValid, isTrue);
      expect(invalid.isValid, isFalse);
    });
  });
}

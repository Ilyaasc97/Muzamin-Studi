import 'package:flutter_test/flutter_test.dart';
import 'package:tafsir_timing_tool/models/timing_entry.dart';

void main() {
  group('TimingEntry / SyncSegment', () {
    test('formatTime يعرض دقائق وثوانٍ ومللي ثانية بشكل صحيح', () {
      expect(TimingEntry.formatTime(0), '00:00.000');
      expect(TimingEntry.formatTime(1000), '00:01.000');
      expect(TimingEntry.formatTime(60000), '01:00.000');
      expect(TimingEntry.formatTime(65250), '01:05.250');
      expect(TimingEntry.formatTime(599999), '09:59.999');
    });

    test('formatTime يدعم الساعات للدروس الطويلة', () {
      expect(TimingEntry.formatTime(3600000), '1:00:00.000');
      expect(TimingEntry.formatTime(3600125), '1:00:00.125');
      expect(TimingEntry.formatTime(7200000), '2:00:00.000');
      expect(TimingEntry.formatTime(10800000), '3:00:00.000');
    });

    test('durationMs يحسب الفرق بين البداية والنهاية', () {
      const entry = TimingEntry(
        id: 1,
        verseNumber: 1,
        startMs: 1000,
        endMs: 4500,
      );
      expect(entry.durationMs, 3500);
    });

    test('isValid يتحقق من أن النهاية أكبر من البداية', () {
      const valid = TimingEntry(
        id: 1,
        verseNumber: 1,
        startMs: 100,
        endMs: 200,
      );
      expect(valid.isValid, true);

      const invalid = TimingEntry(
        id: 2,
        verseNumber: 2,
        startMs: 300,
        endMs: 300,
      );
      expect(invalid.isValid, false);
    });

    test('يدعم جميع أنواع المقاطع (SegmentType)', () {
      expect(SegmentType.values.length, 5);
      expect(SegmentType.fromString('quran'), SegmentType.quran);
      expect(SegmentType.fromString('hadith'), SegmentType.hadith);
      expect(SegmentType.fromString('chapter'), SegmentType.chapter);
      expect(SegmentType.fromString('dhikr'), SegmentType.dhikr);
      expect(SegmentType.fromString('custom'), SegmentType.custom);
      expect(SegmentType.fromString('UNKNOWN'), SegmentType.quran);
    });

    test('toJson يحول الإدخال إلى Map متوافق مع Schema v2 ويشمل رقم الصفحة والجزء', () {
      const entry = TimingEntry(
        id: 1,
        verseNumber: 3,
        startMs: 1000,
        endMs: 4500,
        type: SegmentType.hadith,
        page: 10,
        label: 'حديث النية',
        textArabic: 'إنما الأعمال بالنيات',
      );
      final json = entry.toJson(includeText: true);

      expect(json['id'], 1);
      expect(json['number'], 3);
      expect(json['verseNumber'], 3);
      expect(json['type'], 'hadith');
      expect(json['page'], 10);
      expect(json['juz'], 1);
      expect(json['startMs'], 1000);
      expect(json['endMs'], 4500);
      expect(json['durationMs'], 3500);
      expect(json['label'], 'حديث النية');
      expect(json['textArabic'], 'إنما الأعمال بالنيات');
    });

    test('toJson بالوضع الخفيف (includeText: false) لا يتضمن نصوص الآيات لتخفيف الحجم', () {
      const entry = TimingEntry(
        id: 1,
        verseNumber: 3,
        startMs: 1000,
        endMs: 4500,
        type: SegmentType.quran,
        page: 25,
        textArabic: 'نص قرآني',
      );
      final json = entry.toJson(includeText: false);

      expect(json.containsKey('textArabic'), false);
      expect(json['page'], 25);
      expect(json['juz'], 2);
    });

    test('fromJson يستخرج البيانات ويدعم التوافقية العكسية مع Schema v1 ورقم الصفحة', () {
      // ملف قديم بـ Schema v1
      final legacyJson = <String, dynamic>{
        'verseNumber': 5,
        'startMs': 2000,
        'endMs': 5000,
      };
      final legacyEntry = TimingEntry.fromJson(legacyJson);

      expect(legacyEntry.verseNumber, 5);
      expect(legacyEntry.startMs, 2000);
      expect(legacyEntry.endMs, 5000);
      expect(legacyEntry.type, SegmentType.quran);
      expect(legacyEntry.page, null);
      expect(legacyEntry.label, null);

      // ملف جديد بـ Schema v2 مع page
      final v2Json = <String, dynamic>{
        'id': 10,
        'number': 62,
        'page': 10,
        'type': 'quran',
        'startMs': 0,
        'endMs': 341468,
        'label': 'سورة البقرة 62',
      };
      final v2Entry = TimingEntry.fromJson(v2Json);

      expect(v2Entry.id, 10);
      expect(v2Entry.verseNumber, 62);
      expect(v2Entry.page, 10);
      expect(v2Entry.type, SegmentType.quran);
      expect(v2Entry.label, 'سورة البقرة 62');
    });

    test('copyWith ينسخ الإدخال مع تعديل الحقول ورقم الصفحة', () {
      const original = TimingEntry(
        id: 1,
        verseNumber: 1,
        startMs: 1000,
        endMs: 2000,
        type: SegmentType.quran,
        page: 10,
      );

      final modified = original.copyWith(
        verseNumber: 2,
        page: 11,
        type: SegmentType.hadith,
        label: 'حديث شريف',
      );

      expect(modified.id, 1);
      expect(modified.verseNumber, 2);
      expect(modified.page, 11);
      expect(modified.type, SegmentType.hadith);
      expect(modified.label, 'حديث شريف');
      expect(modified.startMs, 1000);
      expect(modified.endMs, 2000);
    });

    test('المساواة (operator ==) والـ hashCode تعمل بشكل صحيح مع الحقول والصفحة', () {
      const entry1 = TimingEntry(
        id: 1,
        verseNumber: 1,
        startMs: 1000,
        endMs: 2000,
        type: SegmentType.quran,
        page: 10,
      );

      const entry2 = TimingEntry(
        id: 1,
        verseNumber: 1,
        startMs: 1000,
        endMs: 2000,
        type: SegmentType.quran,
        page: 10,
      );

      const entry3 = TimingEntry(
        id: 1,
        verseNumber: 1,
        startMs: 1000,
        endMs: 2000,
        type: SegmentType.quran,
        page: 11,
      );

      expect(entry1 == entry2, true);
      expect(entry1.hashCode == entry2.hashCode, true);
      expect(entry1 == entry3, false);
    });

    test('roundTrip JSON: fromJson(toJson()) يحافظ على جميع البيانات بما فيها page', () {
      const original = TimingEntry(
        id: 42,
        verseNumber: 62,
        startMs: 0,
        endMs: 341468,
        type: SegmentType.quran,
        page: 10,
        label: 'سورة البقرة 62',
        textArabic: 'إِنَّ الَّذِينَ آمَنُوا وَالَّذِينَ هَادُوا...',
      );

      final json = original.toJson(includeText: true);
      final restored = TimingEntry.fromJson(json);

      expect(restored, original);
      expect(restored.page, 10);
      expect(restored.durationMs, original.durationMs);
    });
  });
}

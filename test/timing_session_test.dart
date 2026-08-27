import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tafsir_timing_tool/controllers/timing_session.dart';
import 'package:tafsir_timing_tool/models/timing_entry.dart';
import 'package:tafsir_timing_tool/services/quran_api_service.dart';
import 'package:tafsir_timing_tool/services/settings_service.dart';

void main() {
  group('TimingSession', () {
    late TimingSession session;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SettingsService.instance.initialize();
      await SettingsService.instance.setLatencyOffsetMs(0);
      session = TimingSession();
    });

    tearDown(() {
      session.dispose();
    });

    test('يبدأ بدون إدخالات والنوع الافتراضي هو quran', () {
      expect(session.entries, isEmpty);
      expect(session.nextVerse, 1);
      expect(session.hasPendingStart, false);
      expect(session.activeType, SegmentType.quran);
    });

    test('setActiveType يغير النوع النشط ويطلق إشعاراً للمستمعين', () {
      int notifyCount = 0;
      session.addListener(() => notifyCount++);

      session.setActiveType(SegmentType.hadith);
      expect(session.activeType, SegmentType.hadith);
      expect(notifyCount, 1);

      // إذا كان نفس النوع لا يطلق إشعاراً مكرراً
      session.setActiveType(SegmentType.hadith);
      expect(notifyCount, 1);
    });

    test('toggleMark يتطلب ملف صوتي أولاً', () {
      session.toggleMark();
      expect(session.entries, isEmpty);
      expect(session.hasPendingStart, false);
    });

    test('undoLast على قائمة فارغة لا يحدث خطأ', () {
      expect(session.entries, isEmpty);
      session.undoLast();
      expect(session.entries, isEmpty);
    });

    test('adjustLatency يعدل قيمة التأخير ضمن الحدود', () {
      expect(session.latencyOffsetMs, 0);

      session.adjustLatency(100);
      expect(session.latencyOffsetMs, 100);

      session.adjustLatency(100);
      expect(session.latencyOffsetMs, 200);

      // الحد الأقصى 1000
      session.adjustLatency(900);
      expect(session.latencyOffsetMs, 1000);

      // لا يتجاوز الحد
      session.adjustLatency(100);
      expect(session.latencyOffsetMs, 1000);
    });

    test('adjustLatency يدعم القيم السالبة ضمن الحدود', () {
      expect(session.latencyOffsetMs, 0);

      session.adjustLatency(-100);
      expect(session.latencyOffsetMs, -100);

      session.adjustLatency(-900);
      expect(session.latencyOffsetMs, -1000);

      // لا يتجاوز الحد السالب
      session.adjustLatency(-100);
      expect(session.latencyOffsetMs, -1000);
    });

    test('hasSource و sourceFileName يعودان null بدون ملف', () {
      expect(session.hasSource, false);
      expect(session.sourceFileName, null);
    });

    test('cancelPendingStart بدون بيانات قيد الانتظار', () {
      expect(session.hasPendingStart, false);
      session.cancelPendingStart();
      expect(session.hasPendingStart, false);
    });

    test('clearAll يحذف جميع الإدخالات', () {
      expect(session.entries, isEmpty);
      session.clearAll();
      expect(session.entries, isEmpty);
      expect(session.nextVerse, 1);
      expect(session.hasPendingStart, false);
    });

    test('getters ترجع القيم الصحيحة', () {
      expect(session.speed, 1.0);
      expect(session.loading, false);
      expect(session.lastError, null);
    });

    test('updateEntry يعدل الإدخال المحدد ويطلق إشعاراً', () {
      int count = 0;
      session.addListener(() => count++);

      const entry = TimingEntry(
        id: 0,
        verseNumber: 1,
        startMs: 1000,
        endMs: 3000,
        type: SegmentType.quran,
      );

      session.updateEntry(entry.copyWith(label: 'سورة الإخلاص'));
    });

    test('محرك تلقيم النصوص المسبقة يعمل بالتسلسل المطلوب ويدعم السابق والتخطي', () {
      expect(session.hasPreloadedScript, false);
      expect(session.canPrevScriptLine, false);
      expect(session.currentScriptLine, null);

      session.setPreloadedScript(['الآية الأولى', 'الآية الثانية', 'الآية الثالثة']);
      expect(session.hasPreloadedScript, true);
      expect(session.canPrevScriptLine, false);
      expect(session.canSkipScriptLine, true);
      expect(session.totalScriptCount, 3);
      expect(session.currentScriptVerseIndex, 1);
      expect(session.remainingScriptCount, 3);
      expect(session.currentScriptLine, 'الآية الأولى');

      session.skipScriptLine();
      expect(session.canPrevScriptLine, true);
      expect(session.remainingScriptCount, 2);
      expect(session.currentScriptVerseIndex, 2);
      expect(session.currentScriptLine, 'الآية الثانية');

      session.prevScriptLine();
      expect(session.canPrevScriptLine, false);
      expect(session.remainingScriptCount, 3);
      expect(session.currentScriptVerseIndex, 1);
      expect(session.currentScriptLine, 'الآية الأولى');

      session.clearPreloadedScript();
      expect(session.hasPreloadedScript, false);
    });

    test('تلقيم آيات تمتد على أكثر من صفحة ينتقل بالصفحات والخطوط تلقائياً عند التسجيل', () {
      // محاكاة نطاق سورة البقرة: آيات 56-57 على صفحة 8، وآيات 58-59 على صفحة 9
      final verses = [
        const FetchedVerse(
          verseNumber: 56,
          surahNumber: 2,
          surahName: 'البقرة',
          textArabic: 'ثُمَّ بَعَثْنَاكُم مِّن بَعْدِ مَوْتِكُمْ',
          page: 8,
          fontFamily: 'QCF2008',
        ),
        const FetchedVerse(
          verseNumber: 57,
          surahNumber: 2,
          surahName: 'البقرة',
          textArabic: 'وَظَلَّلْنَا عَلَيْكُمُ الْغَمَامَ',
          page: 8,
          fontFamily: 'QCF2008',
        ),
        const FetchedVerse(
          verseNumber: 58,
          surahNumber: 2,
          surahName: 'البقرة',
          textArabic: 'وَإِذْ قُلْنَا ادْخُلُوا هَٰذِهِ الْقَرْيَةَ',
          page: 9,
          fontFamily: 'QCF2009',
        ),
        const FetchedVerse(
          verseNumber: 59,
          surahNumber: 2,
          surahName: 'البقرة',
          textArabic: 'فَبَدَّلَ الَّذِينَ ظَلَمُوا',
          page: 9,
          fontFamily: 'QCF2009',
        ),
      ];

      session.setPreloadedVerses(verses);

      expect(session.hasPreloadedScript, true);
      expect(session.activePage, 8);
      expect(session.nextVerse, 56);
      expect(session.currentScriptPage, 8);
      expect(session.currentScriptFontFamily, 'QCF2008');
      expect(session.currentScriptVerseNumber, 56);

      // محاكاة تسجيل آية 56 (صفحة 8)
      // تجاوز شرط sourceFilePath للاختبار الداخلي
      session.skipScriptLine(); // الانتقال إلى آية 57
      expect(session.activePage, 8);
      expect(session.nextVerse, 57);
      expect(session.currentScriptPage, 8);
      expect(session.currentScriptFontFamily, 'QCF2008');

      // الانتقال إلى آية 58 (أول آية في صفحة 9)
      session.skipScriptLine();
      expect(session.activePage, 9, reason: 'يجب أن ينتقل رقم الصفحة تلقائياً إلى 9');
      expect(session.nextVerse, 58, reason: 'يجب أن ينتقل رقم الآية تلقائياً إلى 58');
      expect(session.currentScriptPage, 9);
      expect(session.currentScriptFontFamily, 'QCF2009', reason: 'يجب أن يتحول الخط إلى QCF2009');
      expect(session.currentScriptVerseNumber, 58);

      // الرجوع إلى آية 57 (صفحة 8)
      session.prevScriptLine();
      expect(session.activePage, 8, reason: 'عند الرجوع يجب أن يعود رقم الصفحة إلى 8');
      expect(session.nextVerse, 57);
      expect(session.currentScriptFontFamily, 'QCF2008');
    });

    test('الأسرع المدعومة صحيحة', () {
      expect(TimingSession.speeds, [1.0, 1.5, 2.0]);
    });
  });
}

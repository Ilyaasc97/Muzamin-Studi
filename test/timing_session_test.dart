import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tafsir_timing_tool/controllers/timing_session.dart';
import 'package:tafsir_timing_tool/models/timing_entry.dart';
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

    test('الأسرع المدعومة صحيحة', () {
      expect(TimingSession.speeds, [1.0, 1.5, 2.0]);
    });
  });
}

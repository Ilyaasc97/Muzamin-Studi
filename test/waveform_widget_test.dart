import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafsir_timing_tool/models/timing_entry.dart';
import 'package:tafsir_timing_tool/services/waveform_service.dart';
import 'package:tafsir_timing_tool/widgets/waveform_widget.dart';

void main() {
  group('WaveformService', () {
    test('generateFallback يولد نقاط موجة ضمن الحدود المسموحة', () async {
      final service = WaveformService.instance;
      await service.generateFallback(points: 100);

      expect(service.peaks.length, 100);
      for (final peak in service.peaks) {
        expect(peak, greaterThanOrEqualTo(0.05));
        expect(peak, lessThanOrEqualTo(1.0));
      }
    });
  });

  group('WaveformWidget', () {
    testWidgets('يعرض رسالة عند عدم توفر بيانات موجة', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WaveformWidget(
              peaks: const [],
              position: Duration.zero,
              duration: Duration.zero,
              entries: const [],
              onSeek: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    });

    testWidgets('يعرض CustomPaint عندما تتوفر بيانات موجة', (tester) async {
      Duration? soughtDuration;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 140,
              child: WaveformWidget(
                peaks: List.filled(50, 0.5),
                position: const Duration(seconds: 5),
                duration: const Duration(seconds: 10),
                entries: const [
                  TimingEntry(
                    id: 0,
                    verseNumber: 1,
                    startMs: 1000,
                    endMs: 4000,
                    type: SegmentType.quran,
                  ),
                ],
                onSeek: (pos) => soughtDuration = pos,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);

      // اختبار النقر للتقديم
      await tester.tap(find.byType(GestureDetector).first);
      expect(soughtDuration, isNotNull);
    });
  });
}

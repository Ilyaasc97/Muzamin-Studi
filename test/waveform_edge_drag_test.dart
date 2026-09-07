import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafsir_timing_tool/models/timing_entry.dart';
import 'package:tafsir_timing_tool/widgets/waveform_widget.dart';

void main() {
  group('WaveformWidget - Interactive Edge Dragging', () {
    final samplePeaks = List<double>.generate(100, (i) => (i % 10) / 10.0);
    const sampleDuration = Duration(seconds: 10); // 10,000 ms

    // عرض 800px على 10000ms => 0.08 بكسل لكل ملي ثانية
    // startMs = 2000 => startX = 160px
    // endMs = 5000   => endX = 400px
    const double testWidth = 800.0;
    const double testHeight = 140.0;

    final entry1 = TimingEntry(
      id: 1,
      verseNumber: 1,
      startMs: 2000,
      endMs: 5000,
      type: SegmentType.quran,
    );

    Widget buildTestWidget({
      void Function(Duration)? onSeek,
      void Function(TimingEntry)? onEntryChanged,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: testWidth,
              height: testHeight,
              child: WaveformWidget(
                peaks: samplePeaks,
                position: const Duration(seconds: 1),
                duration: sampleDuration,
                entries: [entry1],
                onSeek: onSeek ?? (_) {},
                onEntryChanged: onEntryChanged,
                height: testHeight,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('يرسم الـ WaveformWidget بنجاح مع المقاطع والمقابض', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(WaveformWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('النقر بعيداً عن الحواف يستدعي onSeek العادي (Scrubber Seek)', (tester) async {
      Duration? seekedDuration;
      await tester.pumpWidget(buildTestWidget(
        onSeek: (d) => seekedDuration = d,
      ));

      final widgetFinder = find.byType(WaveformWidget);
      final widgetTopLeft = tester.getTopLeft(widgetFinder);

      // النقر عند x = 80px (80 / 0.08 = 1000ms)، بعيد تماماً عن 160px و 400px
      await tester.tapAt(Offset(widgetTopLeft.dx + 80, widgetTopLeft.dy + 70));
      await tester.pumpAndSettle();

      expect(seekedDuration, isNotNull);
      expect(seekedDuration!.inMilliseconds, closeTo(1000, 50));
    });

    testWidgets('سحب مقبض البداية يميناً يعدل startMs ويستدعي onEntryChanged', (tester) async {
      TimingEntry? updatedEntry;
      await tester.pumpWidget(buildTestWidget(
        onEntryChanged: (entry) => updatedEntry = entry,
      ));

      final widgetFinder = find.byType(WaveformWidget);
      final widgetTopLeft = tester.getTopLeft(widgetFinder);

      // سحب المقبض من خط البداية (160px = 2000ms) بمقدار +40px (ليصل إلى 200px = 2500ms)
      await tester.dragFrom(
        Offset(widgetTopLeft.dx + 160, widgetTopLeft.dy + 70),
        const Offset(40, 0),
      );
      await tester.pumpAndSettle();

      expect(updatedEntry, isNotNull);
      expect(updatedEntry!.id, entry1.id);
      expect(updatedEntry!.startMs, closeTo(2500, 50));
      expect(updatedEntry!.endMs, 5000); // النهاية لم تتغير
    });

    testWidgets('سحب مقبض النهاية يساراً يعدل endMs ويستدعي onEntryChanged', (tester) async {
      TimingEntry? updatedEntry;
      await tester.pumpWidget(buildTestWidget(
        onEntryChanged: (entry) => updatedEntry = entry,
      ));

      final widgetFinder = find.byType(WaveformWidget);
      final widgetTopLeft = tester.getTopLeft(widgetFinder);

      // سحب المقبض من خط النهاية (400px = 5000ms) بمقدار -80px (ليصل إلى 320px = 4000ms)
      await tester.dragFrom(
        Offset(widgetTopLeft.dx + 400, widgetTopLeft.dy + 70),
        const Offset(-80, 0),
      );
      await tester.pumpAndSettle();

      expect(updatedEntry, isNotNull);
      expect(updatedEntry!.id, entry1.id);
      expect(updatedEntry!.startMs, 2000); // البداية لم تتغير
      expect(updatedEntry!.endMs, closeTo(4000, 50));
    });

    testWidgets('قيود الأمان: سحب البداية لا يتجاوز النهاية ناقص 100ms', (tester) async {
      TimingEntry? updatedEntry;
      await tester.pumpWidget(buildTestWidget(
        onEntryChanged: (entry) => updatedEntry = entry,
      ));

      final widgetFinder = find.byType(WaveformWidget);
      final widgetTopLeft = tester.getTopLeft(widgetFinder);

      // محاولة سحب البداية لتتجاوز النهاية (سحب من 160px بمقدار +340px حيث النهاية عند 400px)
      await tester.dragFrom(
        Offset(widgetTopLeft.dx + 160, widgetTopLeft.dy + 70),
        const Offset(340, 0),
      );
      await tester.pumpAndSettle();

      expect(updatedEntry, isNotNull);
      // يجب ألا تتجاوز endMs - 100ms = 4900ms
      expect(updatedEntry!.startMs, lessThanOrEqualTo(4900));
      expect(updatedEntry!.startMs, greaterThanOrEqualTo(4850));
    });
  });
}

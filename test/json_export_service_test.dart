import 'package:flutter_test/flutter_test.dart';
import 'package:tafsir_timing_tool/models/timing_entry.dart';
import 'package:tafsir_timing_tool/services/json_export_service.dart';

void main() {
  group('JsonExportService', () {
    late JsonExportService service;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      service = JsonExportService();
    });

    test('يرمي ExportException إذا كانت القائمة فارغة', () async {
      expect(
        () => service.export(
          lessonId: 'test_lesson',
          audioUrl: '',
          sourceFilePath: null,
          entries: [],
        ),
        throwsA(isA<ExportException>()),
      );
    });

    test('يرمي ExportException إذا كان معرّف الدرس فارغاً', () async {
      expect(
        () => service.export(
          lessonId: '   ',
          audioUrl: '',
          sourceFilePath: null,
          entries: [
            const TimingEntry(
              id: 1,
              verseNumber: 1,
              startMs: 100,
              endMs: 500,
            ),
          ],
        ),
        throwsA(isA<ExportException>()),
      );
    });

    test('يرمي ExportException إذا وجد مقطع غير صالح', () async {
      expect(
        () => service.export(
          lessonId: 'lesson_01',
          audioUrl: '',
          sourceFilePath: null,
          entries: [
            const TimingEntry(
              id: 1,
              verseNumber: 1,
              startMs: 1000,
              endMs: 500, // غير صالح
            ),
          ],
        ),
        throwsA(isA<ExportException>()),
      );
    });
  });
}

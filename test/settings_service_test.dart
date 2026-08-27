import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tafsir_timing_tool/services/settings_service.dart';

void main() {
  group('SettingsService', () {
    final service = SettingsService.instance;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await service.initialize();
    });

    test('يبدأ بالقيم الافتراضية للثيم والتأخير والاختصارات', () {
      expect(service.themeMode, ThemeMode.dark);
      expect(service.latencyOffsetMs, 0);
      expect(service.shortcuts['play_pause'], 'Space');
      expect(service.shortcuts['mark_verse'], 'Enter');
    });

    test('setThemeMode يغير الثيم ويطلق إشعاراً للمستمعين', () async {
      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.setThemeMode(ThemeMode.light);
      expect(service.themeMode, ThemeMode.light);
      expect(notifyCount, 1);

      await service.setThemeMode(ThemeMode.system);
      expect(service.themeMode, ThemeMode.system);
      expect(notifyCount, 2);

      // لا يطلق إشعار إذا تم اختيار نفس الثيم
      await service.setThemeMode(ThemeMode.system);
      expect(notifyCount, 2);
    });

    test('setLatencyOffsetMs يعدل التأخير ويطلق إشعاراً', () async {
      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.setLatencyOffsetMs(150);
      expect(service.latencyOffsetMs, 150);
      expect(notifyCount, 1);

      await service.setLatencyOffsetMs(-200);
      expect(service.latencyOffsetMs, -200);
      expect(notifyCount, 2);
    });

    test('setShortcut يعدل الاختصار ويطلق إشعاراً', () async {
      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.setShortcut('play_pause', 'Control+Space');
      expect(service.shortcuts['play_pause'], 'Control+Space');
      expect(notifyCount, 1);
    });

    test('resetShortcutsToDefault يعيد الاختصارات الافتراضية', () async {
      await service.setShortcut('play_pause', 'F5');
      expect(service.shortcuts['play_pause'], 'F5');

      await service.resetShortcutsToDefault();
      expect(service.shortcuts['play_pause'], 'Space');
    });
  });
}

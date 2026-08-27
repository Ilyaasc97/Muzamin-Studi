import 'package:flutter/services.dart';

import '../core/app_logger.dart';

class QuranFontService {
  QuranFontService._();
  static final QuranFontService instance = QuranFontService._();

  final Set<String> _loadedFamilies = {};

  /// يتحقق من تحميل خط صفحة المصحف ويدمجه ديناميكياً في محرك Flutter
  Future<void> ensurePageFontLoaded(int page) async {
    if (page < 1 || page > 604) return;
    final family = getFontFamilyForPage(page);
    if (_loadedFamilies.contains(family)) return;

    final String pageStr = page.toString().padLeft(3, '0');
    final String assetPath = 'assets/font/font/QCF2$pageStr.ttf';

    try {
      final fontLoader = FontLoader(family);
      fontLoader.addFont(rootBundle.load(assetPath));
      await fontLoader.load();
      _loadedFamilies.add(family);
      AppLogger.instance.info('تم تحميل خط صفحة المصحف بنجاح: $family');
    } catch (e, stack) {
      AppLogger.instance.error('خطأ أثناء تحميل خط الصفحة $page ($assetPath)', e, stack);
    }
  }

  /// إرجاع اسم عائلة الخط المطابق لرقم الصفحة
  static String getFontFamilyForPage(int? page) {
    if (page == null || page < 1 || page > 604) {
      return 'UthmanicHafs';
    }
    final String pageStr = page.toString().padLeft(3, '0');
    return 'QCF2$pageStr';
  }
}

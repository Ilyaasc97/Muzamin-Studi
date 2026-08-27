import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../core/app_logger.dart';
import 'quran_font_service.dart';

class SurahInfo {
  const SurahInfo({
    required this.number,
    required this.nameArabic,
    required this.nameEnglish,
    required this.totalVerses,
  });

  final int number;
  final String nameArabic;
  final String nameEnglish;
  final int totalVerses;

  @override
  String toString() => '$number. $nameArabic ($nameEnglish)';
}

class FetchedVerse {
  const FetchedVerse({
    required this.verseNumber,
    required this.surahNumber,
    required this.surahName,
    required this.textArabic,
    this.page,
    this.fontFamily,
  });

  final int verseNumber;
  final int surahNumber;
  final String surahName;
  final String textArabic;
  final int? page;
  final String? fontFamily;
}

class QuranApiService {
  QuranApiService._();
  static final QuranApiService instance = QuranApiService._();

  static const List<SurahInfo> surahs = [
    SurahInfo(number: 1, nameArabic: 'الفاتحة', nameEnglish: 'Al-Fatihah', totalVerses: 7),
    SurahInfo(number: 2, nameArabic: 'البقرة', nameEnglish: 'Al-Baqarah', totalVerses: 286),
    SurahInfo(number: 3, nameArabic: 'آل عمران', nameEnglish: 'Aal-Imran', totalVerses: 200),
    SurahInfo(number: 4, nameArabic: 'النساء', nameEnglish: 'An-Nisa', totalVerses: 176),
    SurahInfo(number: 5, nameArabic: 'المائدة', nameEnglish: 'Al-Ma\'idah', totalVerses: 120),
    SurahInfo(number: 6, nameArabic: 'الأنعام', nameEnglish: 'Al-An\'am', totalVerses: 165),
    SurahInfo(number: 7, nameArabic: 'الأعراف', nameEnglish: 'Al-A\'raf', totalVerses: 206),
    SurahInfo(number: 8, nameArabic: 'الأنفال', nameEnglish: 'Al-Anfal', totalVerses: 75),
    SurahInfo(number: 9, nameArabic: 'التوبة', nameEnglish: 'At-Tawbah', totalVerses: 129),
    SurahInfo(number: 10, nameArabic: 'يونس', nameEnglish: 'Yunus', totalVerses: 109),
    SurahInfo(number: 11, nameArabic: 'هود', nameEnglish: 'Hud', totalVerses: 123),
    SurahInfo(number: 12, nameArabic: 'يوسف', nameEnglish: 'Yusuf', totalVerses: 111),
    SurahInfo(number: 13, nameArabic: 'الرعد', nameEnglish: 'Ar-Ra\'d', totalVerses: 43),
    SurahInfo(number: 14, nameArabic: 'إبراهيم', nameEnglish: 'Ibrahim', totalVerses: 52),
    SurahInfo(number: 15, nameArabic: 'الحجر', nameEnglish: 'Al-Hijr', totalVerses: 99),
    SurahInfo(number: 16, nameArabic: 'النحل', nameEnglish: 'An-Nahl', totalVerses: 128),
    SurahInfo(number: 17, nameArabic: 'الإسراء', nameEnglish: 'Al-Isra', totalVerses: 111),
    SurahInfo(number: 18, nameArabic: 'الكهف', nameEnglish: 'Al-Kahf', totalVerses: 110),
    SurahInfo(number: 19, nameArabic: 'مريم', nameEnglish: 'Maryam', totalVerses: 98),
    SurahInfo(number: 20, nameArabic: 'طه', nameEnglish: 'Taha', totalVerses: 135),
    SurahInfo(number: 21, nameArabic: 'الأنبياء', nameEnglish: 'Al-Anbiya', totalVerses: 112),
    SurahInfo(number: 22, nameArabic: 'الحج', nameEnglish: 'Al-Hajj', totalVerses: 78),
    SurahInfo(number: 23, nameArabic: 'المؤمنون', nameEnglish: 'Al-Mu\'minun', totalVerses: 118),
    SurahInfo(number: 24, nameArabic: 'النور', nameEnglish: 'An-Nur', totalVerses: 64),
    SurahInfo(number: 25, nameArabic: 'الفرقان', nameEnglish: 'Al-Furqan', totalVerses: 77),
    SurahInfo(number: 26, nameArabic: 'الشعراء', nameEnglish: 'Ash-Shu\'ara', totalVerses: 227),
    SurahInfo(number: 27, nameArabic: 'النمل', nameEnglish: 'An-Naml', totalVerses: 93),
    SurahInfo(number: 28, nameArabic: 'القصص', nameEnglish: 'Al-Qasas', totalVerses: 88),
    SurahInfo(number: 29, nameArabic: 'العنكبوت', nameEnglish: 'Al-Ankabut', totalVerses: 69),
    SurahInfo(number: 30, nameArabic: 'الروم', nameEnglish: 'Ar-Rum', totalVerses: 60),
    SurahInfo(number: 31, nameArabic: 'لقمان', nameEnglish: 'Luqman', totalVerses: 34),
    SurahInfo(number: 32, nameArabic: 'السجدة', nameEnglish: 'As-Sajdah', totalVerses: 30),
    SurahInfo(number: 33, nameArabic: 'الأحزاب', nameEnglish: 'Al-Ahzab', totalVerses: 73),
    SurahInfo(number: 34, nameArabic: 'سبأ', nameEnglish: 'Saba', totalVerses: 54),
    SurahInfo(number: 35, nameArabic: 'فاطر', nameEnglish: 'Fatir', totalVerses: 45),
    SurahInfo(number: 36, nameArabic: 'يس', nameEnglish: 'Ya-Sin', totalVerses: 83),
    SurahInfo(number: 37, nameArabic: 'الصافات', nameEnglish: 'As-Saffat', totalVerses: 182),
    SurahInfo(number: 38, nameArabic: 'ص', nameEnglish: 'Sad', totalVerses: 88),
    SurahInfo(number: 39, nameArabic: 'الزمر', nameEnglish: 'Az-Zumar', totalVerses: 75),
    SurahInfo(number: 40, nameArabic: 'غافر', nameEnglish: 'Ghafir', totalVerses: 85),
    SurahInfo(number: 41, nameArabic: 'فصلت', nameEnglish: 'Fussilat', totalVerses: 54),
    SurahInfo(number: 42, nameArabic: 'الشورى', nameEnglish: 'Ash-Shura', totalVerses: 53),
    SurahInfo(number: 43, nameArabic: 'الزخرف', nameEnglish: 'Az-Zukhruf', totalVerses: 89),
    SurahInfo(number: 44, nameArabic: 'الدخان', nameEnglish: 'Ad-Dukhan', totalVerses: 59),
    SurahInfo(number: 45, nameArabic: 'الجاثية', nameEnglish: 'Al-Jathiyah', totalVerses: 37),
    SurahInfo(number: 46, nameArabic: 'الأحقاف', nameEnglish: 'Al-Ahqaf', totalVerses: 35),
    SurahInfo(number: 47, nameArabic: 'محمد', nameEnglish: 'Muhammad', totalVerses: 38),
    SurahInfo(number: 48, nameArabic: 'الفتح', nameEnglish: 'Al-Fath', totalVerses: 29),
    SurahInfo(number: 49, nameArabic: 'الحجرات', nameEnglish: 'Al-Hujurat', totalVerses: 18),
    SurahInfo(number: 50, nameArabic: 'ق', nameEnglish: 'Qaf', totalVerses: 45),
    SurahInfo(number: 51, nameArabic: 'الذاريات', nameEnglish: 'Adh-Dhariyat', totalVerses: 60),
    SurahInfo(number: 52, nameArabic: 'الطور', nameEnglish: 'At-Tur', totalVerses: 49),
    SurahInfo(number: 53, nameArabic: 'النجم', nameEnglish: 'An-Najm', totalVerses: 62),
    SurahInfo(number: 54, nameArabic: 'القمر', nameEnglish: 'Al-Qamar', totalVerses: 55),
    SurahInfo(number: 55, nameArabic: 'الرحمن', nameEnglish: 'Ar-Rahman', totalVerses: 78),
    SurahInfo(number: 56, nameArabic: 'الواقعة', nameEnglish: 'Al-Waqi\'ah', totalVerses: 96),
    SurahInfo(number: 57, nameArabic: 'الحديد', nameEnglish: 'Al-Hadid', totalVerses: 29),
    SurahInfo(number: 58, nameArabic: 'المجادلة', nameEnglish: 'Al-Mujadila', totalVerses: 22),
    SurahInfo(number: 59, nameArabic: 'الحشر', nameEnglish: 'Al-Hashr', totalVerses: 24),
    SurahInfo(number: 60, nameArabic: 'الممتحنة', nameEnglish: 'Al-Mumtahanah', totalVerses: 13),
    SurahInfo(number: 61, nameArabic: 'الصف', nameEnglish: 'As-Saff', totalVerses: 14),
    SurahInfo(number: 62, nameArabic: 'الجمعة', nameEnglish: 'Al-Jumu\'ah', totalVerses: 11),
    SurahInfo(number: 63, nameArabic: 'المنافقون', nameEnglish: 'Al-Munafiqun', totalVerses: 11),
    SurahInfo(number: 64, nameArabic: 'التغابن', nameEnglish: 'At-Taghabun', totalVerses: 18),
    SurahInfo(number: 65, nameArabic: 'الطلاق', nameEnglish: 'At-Talaq', totalVerses: 12),
    SurahInfo(number: 66, nameArabic: 'التحريم', nameEnglish: 'At-Tahrim', totalVerses: 12),
    SurahInfo(number: 67, nameArabic: 'الملك', nameEnglish: 'Al-Mulk', totalVerses: 30),
    SurahInfo(number: 68, nameArabic: 'القلم', nameEnglish: 'Al-Qalam', totalVerses: 52),
    SurahInfo(number: 69, nameArabic: 'الحاقة', nameEnglish: 'Al-Haqqah', totalVerses: 52),
    SurahInfo(number: 70, nameArabic: 'المعارج', nameEnglish: 'Al-Ma\'arij', totalVerses: 44),
    SurahInfo(number: 71, nameArabic: 'نوح', nameEnglish: 'Nuh', totalVerses: 28),
    SurahInfo(number: 72, nameArabic: 'الجن', nameEnglish: 'Al-Jinn', totalVerses: 28),
    SurahInfo(number: 73, nameArabic: 'المزمل', nameEnglish: 'Al-Muzzammil', totalVerses: 20),
    SurahInfo(number: 74, nameArabic: 'المدثر', nameEnglish: 'Al-Muddaththir', totalVerses: 56),
    SurahInfo(number: 75, nameArabic: 'القيامة', nameEnglish: 'Al-Qiyamah', totalVerses: 40),
    SurahInfo(number: 76, nameArabic: 'الإنسان', nameEnglish: 'Al-Insan', totalVerses: 31),
    SurahInfo(number: 77, nameArabic: 'المرسلات', nameEnglish: 'Al-Mursalat', totalVerses: 50),
    SurahInfo(number: 78, nameArabic: 'النبأ', nameEnglish: 'An-Naba', totalVerses: 40),
    SurahInfo(number: 79, nameArabic: 'النازعات', nameEnglish: 'An-Nazi\'at', totalVerses: 46),
    SurahInfo(number: 80, nameArabic: 'عبس', nameEnglish: 'Abasa', totalVerses: 42),
    SurahInfo(number: 81, nameArabic: 'التكوير', nameEnglish: 'At-Takwir', totalVerses: 29),
    SurahInfo(number: 82, nameArabic: 'الانفطار', nameEnglish: 'Al-Infitar', totalVerses: 19),
    SurahInfo(number: 83, nameArabic: 'المطففين', nameEnglish: 'Al-Mutaffifin', totalVerses: 36),
    SurahInfo(number: 84, nameArabic: 'الانشقاق', nameEnglish: 'Al-Inshiqaq', totalVerses: 25),
    SurahInfo(number: 85, nameArabic: 'البروج', nameEnglish: 'Al-Buruj', totalVerses: 22),
    SurahInfo(number: 86, nameArabic: 'الطارق', nameEnglish: 'At-Tariq', totalVerses: 17),
    SurahInfo(number: 87, nameArabic: 'الأعلى', nameEnglish: 'Al-A\'la', totalVerses: 19),
    SurahInfo(number: 88, nameArabic: 'الغاشية', nameEnglish: 'Al-Ghashiyah', totalVerses: 26),
    SurahInfo(number: 89, nameArabic: 'الفجر', nameEnglish: 'Al-Fajr', totalVerses: 30),
    SurahInfo(number: 90, nameArabic: 'البلد', nameEnglish: 'Al-Balad', totalVerses: 20),
    SurahInfo(number: 91, nameArabic: 'الشمس', nameEnglish: 'Ash-Shams', totalVerses: 15),
    SurahInfo(number: 92, nameArabic: 'الليل', nameEnglish: 'Al-Layl', totalVerses: 21),
    SurahInfo(number: 93, nameArabic: 'الضحى', nameEnglish: 'Ad-Duha', totalVerses: 11),
    SurahInfo(number: 94, nameArabic: 'الشرح', nameEnglish: 'Ash-Sharh', totalVerses: 8),
    SurahInfo(number: 95, nameArabic: 'التين', nameEnglish: 'At-Tin', totalVerses: 8),
    SurahInfo(number: 96, nameArabic: 'العلق', nameEnglish: 'Al-Alaq', totalVerses: 19),
    SurahInfo(number: 97, nameArabic: 'القدر', nameEnglish: 'Al-Qadr', totalVerses: 5),
    SurahInfo(number: 98, nameArabic: 'البينة', nameEnglish: 'Al-Bayyinah', totalVerses: 8),
    SurahInfo(number: 99, nameArabic: 'الزلزلة', nameEnglish: 'Az-Zalzalah', totalVerses: 8),
    SurahInfo(number: 100, nameArabic: 'العاديات', nameEnglish: 'Al-Adiyat', totalVerses: 11),
    SurahInfo(number: 101, nameArabic: 'القارعة', nameEnglish: 'Al-Qari\'ah', totalVerses: 11),
    SurahInfo(number: 102, nameArabic: 'التكاثر', nameEnglish: 'At-Takathur', totalVerses: 8),
    SurahInfo(number: 103, nameArabic: 'العصر', nameEnglish: 'Al-Asr', totalVerses: 3),
    SurahInfo(number: 104, nameArabic: 'الهمزة', nameEnglish: 'Al-Humazah', totalVerses: 9),
    SurahInfo(number: 105, nameArabic: 'الفيل', nameEnglish: 'Al-Fil', totalVerses: 5),
    SurahInfo(number: 106, nameArabic: 'قريش', nameEnglish: 'Quraysh', totalVerses: 4),
    SurahInfo(number: 107, nameArabic: 'الماعون', nameEnglish: 'Al-Ma\'un', totalVerses: 7),
    SurahInfo(number: 108, nameArabic: 'الكوثر', nameEnglish: 'Al-Kawthar', totalVerses: 3),
    SurahInfo(number: 109, nameArabic: 'الكافرون', nameEnglish: 'Al-Kafirun', totalVerses: 6),
    SurahInfo(number: 110, nameArabic: 'النصر', nameEnglish: 'An-Nasr', totalVerses: 3),
    SurahInfo(number: 111, nameArabic: 'المسد', nameEnglish: 'Al-Masad', totalVerses: 5),
    SurahInfo(number: 112, nameArabic: 'الإخلاص', nameEnglish: 'Al-Ikhlas', totalVerses: 4),
    SurahInfo(number: 113, nameArabic: 'الفلق', nameEnglish: 'Al-Falaq', totalVerses: 5),
    SurahInfo(number: 114, nameArabic: 'الناس', nameEnglish: 'An-Nas', totalVerses: 6),
  ];

  static SurahInfo? getSurahByNumber(int num) {
    if (num < 1 || num > 114) return null;
    return surahs[num - 1];
  }

  Map<int, List<FetchedVerse>>? _surahVerseMap;
  Map<int, List<FetchedVerse>>? _pageVerseMap;
  bool _isGlyphDataLoaded = false;

  Future<void> _loadLocalGlyphsData() async {
    if (_isGlyphDataLoaded) return;
    try {
      final jsonString = await rootBundle.loadString('assets/data/quran-glyphs.json');
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final ayatList = (data['ayat'] as List<dynamic>?) ?? [];

      final surahMap = <int, List<FetchedVerse>>{};
      final pageMap = <int, List<FetchedVerse>>{};

      for (final item in ayatList) {
        final surahNum = item['surah'] as int? ?? 1;
        final ayahNum = item['ayah'] as int? ?? 1;
        final chunks = (item['chunks'] as List<dynamic>?) ?? [];
        if (chunks.isEmpty) continue;

        final surah = getSurahByNumber(surahNum);
        final surahName = surah?.nameArabic ?? 'سورة $surahNum';

        // دمج أجزاء الآية مع استخراج رقم الصفحة وعائلة الخط
        final fullText = chunks.map((c) => (c['text'] as String? ?? '').trim()).join(' ');
        final primaryPage = chunks.first['p'] as int? ?? 1;
        final family = QuranFontService.getFontFamilyForPage(primaryPage);

        final verse = FetchedVerse(
          verseNumber: ayahNum,
          surahNumber: surahNum,
          surahName: surahName,
          textArabic: fullText,
          page: primaryPage,
          fontFamily: family,
        );

        surahMap.putIfAbsent(surahNum, () => []).add(verse);
        pageMap.putIfAbsent(primaryPage, () => []).add(verse);
      }

      _surahVerseMap = surahMap;
      _pageVerseMap = pageMap;
      _isGlyphDataLoaded = true;
      AppLogger.instance.info('تم تحميل بيانات مصحف المدينة محلياً: ${ayatList.length} آية');
    } catch (e, stack) {
      AppLogger.instance.warn('تعذر تحميل بيانات مصحف المدينة محلياً، سيتم استخدام الـ API كاحتياط', e, stack);
    }
  }

  Future<List<FetchedVerse>> fetchVersesByRange({
    required int surahNumber,
    required int fromVerse,
    required int toVerse,
  }) async {
    await _loadLocalGlyphsData();

    if (_surahVerseMap != null && _surahVerseMap!.containsKey(surahNumber)) {
      final allSurahVerses = _surahVerseMap![surahNumber]!;
      final filtered = allSurahVerses
          .where((v) => v.verseNumber >= fromVerse && v.verseNumber <= toVerse)
          .toList();

      // تحميل خطوط الصفحات المشمولة في النطاق ديناميكياً
      final pages = filtered.map((v) => v.page).whereType<int>().toSet();
      for (final page in pages) {
        await QuranFontService.instance.ensurePageFontLoaded(page);
      }

      return filtered;
    }

    // احتياطي عبر الإنترنت إذا لم تتوفر البيانات المحلية
    final surah = getSurahByNumber(surahNumber);
    final surahName = surah?.nameArabic ?? 'سورة $surahNumber';

    final uri = Uri.parse('https://api.alquran.cloud/v1/surah/$surahNumber/quran-uthmani');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('Failed to load Quran text: HTTP ${response.statusCode}');
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final ayahs = (data['data']?['ayahs'] as List<dynamic>?) ?? [];

      final results = <FetchedVerse>[];
      for (final ayah in ayahs) {
        final numberInSurah = ayah['numberInSurah'] as int? ?? 0;
        if (numberInSurah >= fromVerse && numberInSurah <= toVerse) {
          final page = ayah['page'] as int?;
          final text = (ayah['text'] as String? ?? '').trim();
          if (page != null) {
            await QuranFontService.instance.ensurePageFontLoaded(page);
          }
          results.add(
            FetchedVerse(
              verseNumber: numberInSurah,
              surahNumber: surahNumber,
              surahName: surahName,
              textArabic: text,
              page: page,
              fontFamily: QuranFontService.getFontFamilyForPage(page),
            ),
          );
        }
      }
      return results;
    } finally {
      client.close();
    }
  }

  Future<List<FetchedVerse>> fetchVersesByPage(int pageNumber) async {
    await _loadLocalGlyphsData();

    if (_pageVerseMap != null && _pageVerseMap!.containsKey(pageNumber)) {
      final pageVerses = _pageVerseMap![pageNumber]!;
      await QuranFontService.instance.ensurePageFontLoaded(pageNumber);
      return pageVerses;
    }

    // احتياطي عبر الإنترنت إذا لم تتوفر البيانات المحلية
    final uri = Uri.parse('https://api.alquran.cloud/v1/page/$pageNumber/quran-uthmani');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);

    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('Failed to load Quran page: HTTP ${response.statusCode}');
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final ayahs = (data['data']?['ayahs'] as List<dynamic>?) ?? [];

      await QuranFontService.instance.ensurePageFontLoaded(pageNumber);

      final results = <FetchedVerse>[];
      for (final ayah in ayahs) {
        final numberInSurah = ayah['numberInSurah'] as int? ?? 0;
        final surahData = ayah['surah'] as Map<String, dynamic>?;
        final surahNumber = surahData?['number'] as int? ?? 0;
        final surahName = (surahData?['name'] as String?) ?? 'سورة $surahNumber';
        final text = (ayah['text'] as String? ?? '').trim();

        results.add(
          FetchedVerse(
            verseNumber: numberInSurah,
            surahNumber: surahNumber,
            surahName: surahName,
            textArabic: text,
            page: pageNumber,
            fontFamily: QuranFontService.getFontFamilyForPage(pageNumber),
          ),
        );
      }
      return results;
    } finally {
      client.close();
    }
  }
}

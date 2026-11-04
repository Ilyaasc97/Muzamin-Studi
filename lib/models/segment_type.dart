import 'package:flutter/material.dart';

enum SegmentType {
  quran,
  hadith,
  chapter,
  dhikr,
  custom;

  String get nameKey => 'segment_types.$name';
  String get shortNameKey => 'segment_types.${name}_short';

  Color get color => colorFor(Brightness.dark);

  Color colorFor(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;
    switch (this) {
      case SegmentType.quran:
        return isLight ? const Color(0xFF0F766E) : const Color(0xFF2DD4BF); // Teal 700 vs Teal 400
      case SegmentType.hadith:
        return isLight ? const Color(0xFFB45309) : const Color(0xFFFBBF24); // Amber 700 vs Amber 400
      case SegmentType.chapter:
        return isLight ? const Color(0xFF1D4ED8) : const Color(0xFF60A5FA); // Blue 700 vs Blue 400
      case SegmentType.dhikr:
        return isLight ? const Color(0xFF6D28D9) : const Color(0xFFA78BFA); // Purple 700 vs Purple 400
      case SegmentType.custom:
        return isLight ? const Color(0xFFBE123C) : const Color(0xFFF87171); // Rose 700 vs Rose 400
    }
  }

  Color bgBadgeFor(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;
    switch (this) {
      case SegmentType.quran:
        return isLight ? const Color(0xFFCCFBF1) : const Color(0x332DD4BF);
      case SegmentType.hadith:
        return isLight ? const Color(0xFFFEF3C7) : const Color(0x33FBBF24);
      case SegmentType.chapter:
        return isLight ? const Color(0xFFDBEAFE) : const Color(0x3360A5FA);
      case SegmentType.dhikr:
        return isLight ? const Color(0xFFEDE9FE) : const Color(0x33A78BFA);
      case SegmentType.custom:
        return isLight ? const Color(0xFFFFE4E6) : const Color(0x33F87171);
    }
  }

  IconData get icon {
    switch (this) {
      case SegmentType.quran:
        return Icons.menu_book_rounded;
      case SegmentType.hadith:
        return Icons.auto_stories_rounded;
      case SegmentType.chapter:
        return Icons.bookmark_rounded;
      case SegmentType.dhikr:
        return Icons.spa_rounded;
      case SegmentType.custom:
        return Icons.edit_note_rounded;
    }
  }

  int get hotkeyNumber {
    switch (this) {
      case SegmentType.quran:
        return 1;
      case SegmentType.hadith:
        return 2;
      case SegmentType.chapter:
        return 3;
      case SegmentType.dhikr:
        return 4;
      case SegmentType.custom:
        return 5;
    }
  }

  static SegmentType fromString(String? raw) {
    if (raw == null) return SegmentType.quran;
    return SegmentType.values.firstWhere(
      (e) => e.name.toLowerCase() == raw.toLowerCase(),
      orElse: () => SegmentType.quran,
    );
  }
}

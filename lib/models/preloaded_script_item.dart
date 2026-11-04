import 'segment_type.dart';
import '../services/quran_api_service.dart';

/// يمثل عنصراً أو آية ملقمة مسبقاً في شريط التلقيم التلقائي
class PreloadedScriptItem {
  const PreloadedScriptItem({
    required this.text,
    this.verseNumber,
    this.surahNumber,
    this.surahName,
    this.page,
    this.fontFamily,
    this.segmentType = SegmentType.quran,
  });

  final String text;
  final int? verseNumber;
  final int? surahNumber;
  final String? surahName;
  final int? page;
  final String? fontFamily;
  final SegmentType? segmentType;

  factory PreloadedScriptItem.fromFetchedVerse(FetchedVerse verse) {
    return PreloadedScriptItem(
      text: verse.textArabic,
      verseNumber: verse.verseNumber,
      surahNumber: verse.surahNumber,
      surahName: verse.surahName,
      page: verse.page,
      fontFamily: verse.fontFamily,
      segmentType: SegmentType.quran,
    );
  }

  factory PreloadedScriptItem.fromJson(dynamic json) {
    if (json is String) {
      return PreloadedScriptItem(text: json);
    }
    final map = json as Map<String, dynamic>;
    return PreloadedScriptItem(
      text: map['text'] as String? ?? '',
      verseNumber: map['verseNumber'] as int?,
      surahNumber: map['surahNumber'] as int?,
      surahName: map['surahName'] as String?,
      page: map['page'] as int?,
      fontFamily: map['fontFamily'] as String?,
      segmentType: map['segmentType'] != null
          ? SegmentType.fromString(map['segmentType'] as String?)
          : SegmentType.quran,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'text': text,
      if (verseNumber != null) 'verseNumber': verseNumber,
      if (surahNumber != null) 'surahNumber': surahNumber,
      if (surahName != null) 'surahName': surahName,
      if (page != null) 'page': page,
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (segmentType != null) 'segmentType': segmentType!.name,
    };
  }

  PreloadedScriptItem copyWith({
    String? text,
    int? verseNumber,
    int? surahNumber,
    String? surahName,
    int? page,
    String? fontFamily,
    SegmentType? segmentType,
  }) {
    return PreloadedScriptItem(
      text: text ?? this.text,
      verseNumber: verseNumber ?? this.verseNumber,
      surahNumber: surahNumber ?? this.surahNumber,
      surahName: surahName ?? this.surahName,
      page: page ?? this.page,
      fontFamily: fontFamily ?? this.fontFamily,
      segmentType: segmentType ?? this.segmentType,
    );
  }
}

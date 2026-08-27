// lib/models/timing_entry.dart
import 'segment_type.dart';

export 'segment_type.dart';

/// يمثل مقطع توقيت زمني موحد (SyncSegment / TimingEntry)
/// متوافق مع المخططين Schema v1 و Schema v2
class TimingEntry {
  const TimingEntry({
    required this.id,
    required this.verseNumber,
    required this.startMs,
    required this.endMs,
    this.type = SegmentType.quran,
    this.page,
    this.label,
    this.textArabic,
  });

  final int id;

  /// الرقم التسلسلي للمقطع أو الآية
  final int verseNumber;

  /// وقت البداية بالمللي ثانية
  final int startMs;

  /// وقت النهاية بالمللي ثانية
  final int endMs;

  /// نوع المقطع (آية، حديث، فصل، ذكر، فقرة)
  final SegmentType type;

  /// رقم صفحة المصحف أو الكتاب (اختياري)
  final int? page;

  /// عنوان مخصص أو وصف للفقرة/المقطع (اختياري)
  final String? label;

  /// النص العربي الأصلي إن وجد (اختياري)
  final String? textArabic;

  /// مدة المقطع بالمللي ثانية
  int get durationMs => endMs - startMs;

  /// هل التوقيت صالح هندسياً
  bool get isValid => endMs > startMs;

  /// رقم الجزء في المصحف الشريف (محسوب تلقائياً من رقم الصفحة)
  int? get juz => page != null ? getJuzForPage(page!) : null;

  /// حساب رقم الجزء في مصحف المدينة (1 إلى 30) بناءً على رقم الصفحة (1 إلى 604)
  static int getJuzForPage(int page) {
    if (page <= 1) return 1;
    if (page >= 582) return 30;
    return ((page - 2) ~/ 20) + 1;
  }

  /// العنوان الفعال للعرض
  String get effectiveLabel {
    if (label != null && label!.isNotEmpty) return label!;
    if (type == SegmentType.quran) return 'الآية $verseNumber';
    return '${type.nameKey} #$verseNumber';
  }

  TimingEntry copyWith({
    int? id,
    int? verseNumber,
    int? startMs,
    int? endMs,
    SegmentType? type,
    int? page,
    String? label,
    String? textArabic,
  }) {
    return TimingEntry(
      id: id ?? this.id,
      verseNumber: verseNumber ?? this.verseNumber,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      type: type ?? this.type,
      page: page ?? this.page,
      label: label ?? this.label,
      textArabic: textArabic ?? this.textArabic,
    );
  }

  Map<String, dynamic> toJson({bool includeText = false}) {
    final map = <String, dynamic>{
      'id': id,
      'type': type.name,
      'verseNumber': verseNumber,
      'number': verseNumber,
      'startMs': startMs,
      'endMs': endMs,
      'durationMs': durationMs,
    };
    if (page != null) {
      map['page'] = page;
      map['juz'] = juz;
    }
    if (label != null && label!.isNotEmpty) {
      map['label'] = label;
    }
    if (includeText && textArabic != null && textArabic!.isNotEmpty) {
      map['textArabic'] = textArabic;
    }
    return map;
  }

  factory TimingEntry.fromJson(Map<String, dynamic> json) {
    final int number =
        (json['number'] as int?) ?? (json['verseNumber'] as int?) ?? 1;

    final String? typeRaw = json['type'] as String?;
    final SegmentType segmentType = typeRaw != null
        ? SegmentType.fromString(typeRaw)
        : SegmentType.quran;

    return TimingEntry(
      id: (json['id'] as int?) ?? 0,
      verseNumber: number,
      startMs: (json['startMs'] as int?) ?? 0,
      endMs: (json['endMs'] as int?) ?? 0,
      type: segmentType,
      page: json['page'] as int?,
      label: json['label'] as String?,
      textArabic: json['textArabic'] as String?,
    );
  }

  static String formatTime(int totalMs) {
    final int ms = totalMs % 1000;
    final int totalSeconds = totalMs ~/ 1000;
    final int s = totalSeconds % 60;
    final int m = (totalSeconds ~/ 60) % 60;
    final int h = totalSeconds ~/ 3600;

    final String sStr = s.toString().padLeft(2, '0');
    final String mStr = m.toString().padLeft(2, '0');
    final String msStr = ms.toString().padLeft(3, '0');

    if (h > 0) {
      return '$h:$mStr:$sStr.$msStr';
    }
    return '$mStr:$sStr.$msStr';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimingEntry &&
        other.id == id &&
        other.verseNumber == verseNumber &&
        other.startMs == startMs &&
        other.endMs == endMs &&
        other.type == type &&
        other.page == page &&
        other.label == label &&
        other.textArabic == textArabic;
  }

  @override
  int get hashCode => Object.hash(
        id,
        verseNumber,
        startMs,
        endMs,
        type,
        page,
        label,
        textArabic,
      );
}

typedef SyncSegment = TimingEntry;

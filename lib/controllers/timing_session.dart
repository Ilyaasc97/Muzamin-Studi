import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_logger.dart';
import '../models/timing_entry.dart';
import '../services/settings_service.dart';
import '../services/waveform_service.dart';

class TimingSession extends ChangeNotifier {
  TimingSession() {
    _latencyOffsetMs = SettingsService.instance.latencyOffsetMs;
    _initAutoSave();
    _loadFromBackup();
  }

  Timer? _autoSaveTimer;

  final AudioPlayer player = AudioPlayer();

  static const List<double> speeds = <double>[1.0, 1.5, 2.0];

  static const List<XTypeGroup> audioTypeGroups = <XTypeGroup>[
    XTypeGroup(
      label: 'ملفات صوتية',
      extensions: <String>['mp3', 'm4a', 'aac', 'wav', 'ogg', 'opus'],
    ),
  ];

  final List<TimingEntry> _entries = <TimingEntry>[];
  final List<String> _preloadedScript = <String>[];
  int _scriptIndex = 0;

  int _idCounter = 0;
  int _nextVerse = 1;
  int? _pendingStartMs;
  double _speed = 1.0;
  int _latencyOffsetMs = 0;
  SegmentType _activeType = SegmentType.quran;
  int? _activePage;
  String? _sourceFilePath;
  String? _lastError;
  bool _loading = false;

  String? _importedLessonId;
  String? _importedAudioUrl;

  List<TimingEntry> get entries => List<TimingEntry>.unmodifiable(_entries);
  List<String> get preloadedScript => List<String>.unmodifiable(_preloadedScript);
  int get scriptIndex => _scriptIndex;
  bool get hasPreloadedScript =>
      _preloadedScript.isNotEmpty && _scriptIndex < _preloadedScript.length;
  bool get canPrevScriptLine => _preloadedScript.isNotEmpty && _scriptIndex > 0;
  bool get canSkipScriptLine => hasPreloadedScript;
  int get totalScriptCount => _preloadedScript.length;
  int get currentScriptVerseIndex => _scriptIndex + 1;
  String? get currentScriptLine =>
      hasPreloadedScript ? _preloadedScript[_scriptIndex] : null;
  int get remainingScriptCount =>
      hasPreloadedScript ? _preloadedScript.length - _scriptIndex : 0;

  bool get hasPendingStart => _pendingStartMs != null;
  int? get pendingStartMs => _pendingStartMs;
  int get nextVerse => _nextVerse;
  double get speed => _speed;
  int get latencyOffsetMs => _latencyOffsetMs;
  SegmentType get activeType => _activeType;
  int? get activePage => _activePage;
  String? get sourceFilePath => _sourceFilePath;
  String? get lastError => _lastError;
  bool get loading => _loading;
  bool get hasSource => _sourceFilePath != null;
  String? get sourceFileName =>
      _sourceFilePath == null ? null : p.basename(_sourceFilePath!);
  String? get importedLessonId => _importedLessonId;
  String? get importedAudioUrl => _importedAudioUrl;

  void setActiveType(SegmentType type) {
    if (_activeType == type) return;
    _activeType = type;
    notifyListeners();
  }

  void setActivePage(int? page) {
    if (_activePage == page) return;
    _activePage = page;
    notifyListeners();
  }

  void incrementPage() {
    _activePage = (_activePage ?? 0) + 1;
    notifyListeners();
  }

  void decrementPage() {
    if (_activePage != null && _activePage! > 1) {
      _activePage = _activePage! - 1;
      notifyListeners();
    }
  }

  void setNextVerse(int num) {
    _nextVerse = math.max(1, num);
    notifyListeners();
  }

  void setPreloadedScript(List<String> lines) {
    _preloadedScript.clear();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        _preloadedScript.add(trimmed);
      }
    }
    _scriptIndex = 0;
    AppLogger.instance.info('تم تحميل ${_preloadedScript.length} نصاً للتلقيم التلقائي');
    notifyListeners();
  }

  void clearPreloadedScript() {
    _preloadedScript.clear();
    _scriptIndex = 0;
    notifyListeners();
  }

  void prevScriptLine() {
    if (_scriptIndex > 0) {
      _scriptIndex--;
      notifyListeners();
    }
  }

  void skipScriptLine() {
    if (hasPreloadedScript) {
      _scriptIndex++;
      notifyListeners();
    }
  }

  Future<String?> pickAndLoadAudio() async {
    try {
      final XFile? file = await openFile(acceptedTypeGroups: audioTypeGroups);
      if (file == null) return null;
      final String lessonId = generateLessonIdFromPath(file.path);
      await loadLocalFile(file.path);
      return lessonId;
    } catch (e, stack) {
      AppLogger.instance.error('خطأ في فتح الملف الصوتي', e, stack);
      return null;
    }
  }

  Future<String?> loadLocalFile(String path) async {
    final String lessonId = generateLessonIdFromPath(path);
    await _loadAudio(
      () => player.setFilePath(path),
      label: p.basename(path),
      filePath: path,
    );
    return lessonId;
  }

  Future<String?> loadRemoteUrl(String rawUrl) async {
    final String url = rawUrl.trim();
    final Uri? uri = Uri.tryParse(url);
    final bool valid =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    if (!valid) {
      _lastError = 'Enter a valid URL starting with http:// or https://';
      notifyListeners();
      return null;
    }
    final String name = p.basename(uri.path);
    final String lessonId = generateLessonIdFromPath(name.isEmpty ? url : name);
    await _loadAudio(
      () => player.setUrl(url),
      label: name.isEmpty ? url : name,
    );
    return lessonId;
  }

  static String generateLessonIdFromPath(String path) {
    final String filename = p.basenameWithoutExtension(path);
    return filename
        .replaceAll(RegExp(r'[<>:"/\\|?*\s]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Future<void> _loadAudio(
    Future<Duration?> Function() load, {
    required String label,
    String? filePath,
  }) async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      await load();
      _sourceFilePath = filePath ?? label;
      _resetEntries();
      if (filePath != null) {
        await WaveformService.instance.generateFromFile(filePath);
      } else {
        await WaveformService.instance.generateFallback();
      }
      AppLogger.instance.info('تم تحميل الملف الصوتي بنجاح: $label');
    } catch (error, stack) {
      _lastError = 'Failed to load file: $error';
      AppLogger.instance.error('فشل تحميل الملف الصوتي', error, stack);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (_sourceFilePath == null) return;
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
    notifyListeners();
  }

  Future<void> setSpeed(double value) async {
    _speed = value;
    await player.setSpeed(value);
    notifyListeners();
  }

  Future<void> seekRelative(int deltaMs) async {
    if (_sourceFilePath == null) return;
    final Duration duration = player.duration ?? Duration.zero;
    int targetMs = player.position.inMilliseconds + deltaMs;
    if (targetMs < 0) targetMs = 0;
    if (duration > Duration.zero && targetMs > duration.inMilliseconds) {
      targetMs = duration.inMilliseconds;
    }
    await player.seek(Duration(milliseconds: targetMs));
  }

  Future<void> replayPendingStart() async {
    final int? start = _pendingStartMs;
    if (start == null) return;
    await player.seek(Duration(milliseconds: start));
    await player.play();
    notifyListeners();
  }

  Future<void> cancelPendingStart() async {
    if (_pendingStartMs == null) return;
    _pendingStartMs = null;
    notifyListeners();
  }

  void toggleMark() {
    if (_sourceFilePath == null) return;
    final int rawMs = player.position.inMilliseconds;
    final int adjustedMs = math.max(0, rawMs - _latencyOffsetMs);

    if (_pendingStartMs == null) {
      _pendingStartMs = adjustedMs;
    } else {
      final int start = _pendingStartMs!;
      final int end = math.max(adjustedMs, start + 1);

      String? attachedText;
      if (hasPreloadedScript) {
        attachedText = _preloadedScript[_scriptIndex++];
      }

      final String? label = attachedText != null && _activeType != SegmentType.quran
          ? attachedText
          : null;
      final String? textArabic = attachedText != null && _activeType == SegmentType.quran
          ? attachedText
          : attachedText;

      _entries.add(TimingEntry(
        id: _idCounter++,
        verseNumber: _nextVerse,
        type: _activeType,
        page: _activePage,
        startMs: start,
        endMs: end,
        label: label,
        textArabic: textArabic,
      ));
      _pendingStartMs = null;
      _nextVerse++;
    }
    notifyListeners();
  }

  void adjustLatency(int deltaMs) {
    _latencyOffsetMs = (_latencyOffsetMs + deltaMs).clamp(-1000, 1000);
    SettingsService.instance.setLatencyOffsetMs(_latencyOffsetMs);
    notifyListeners();
  }

  void updateEntry(TimingEntry updated) {
    final index = _entries.indexWhere((e) => e.id == updated.id);
    if (index != -1) {
      _entries[index] = updated;
      notifyListeners();
    }
  }

  void deleteEntry(int id) {
    _entries.removeWhere((TimingEntry e) => e.id == id);
    _renumberFromListOrder();
    notifyListeners();
  }

  int autoGenerateFromDetectedPauses({
    double silenceThreshold = 0.12,
    int minSilenceMs = 600,
  }) {
    final dur = player.duration;
    if (dur == null || dur <= Duration.zero) return 0;

    final splitPoints = WaveformService.instance.detectPauses(
      totalDuration: dur,
      silenceThreshold: silenceThreshold,
      minSilenceMs: minSilenceMs,
    );

    if (splitPoints.isEmpty) return 0;

    final allPoints = [0, ...splitPoints, dur.inMilliseconds];
    int countCreated = 0;

    for (int i = 0; i < allPoints.length - 1; i++) {
      final start = allPoints[i];
      final end = allPoints[i + 1];
      if (end - start < 800) continue; // skip slivers under 800ms

      String? attachedText;
      if (hasPreloadedScript) {
        attachedText = _preloadedScript[_scriptIndex++];
      }

      final String? label = attachedText != null && _activeType != SegmentType.quran
          ? attachedText
          : null;
      final String? textArabic = attachedText != null && _activeType == SegmentType.quran
          ? attachedText
          : attachedText;

      _entries.add(TimingEntry(
        id: _idCounter++,
        verseNumber: _nextVerse++,
        type: _activeType,
        page: _activePage,
        startMs: start,
        endMs: end,
        label: label,
        textArabic: textArabic,
      ));
      countCreated++;
    }

    notifyListeners();
    return countCreated;
  }

  void undoLast() {
    if (_entries.isEmpty) return;
    _entries.removeLast();
    if (_preloadedScript.isNotEmpty && _scriptIndex > 0) {
      _scriptIndex--;
    }
    _renumberFromListOrder();
    notifyListeners();
  }

  void clearAll() {
    _resetEntries();
    notifyListeners();
  }

  void _resetEntries() {
    _entries.clear();
    _pendingStartMs = null;
    _nextVerse = 1;
  }

  void _renumberFromListOrder() {
    for (int i = 0; i < _entries.length; i++) {
      _entries[i] = _entries[i].copyWith(verseNumber: i + 1);
    }
    _nextVerse = _entries.length + 1;
  }

  /// ═══════════════════════════════════════════════════════════════
  /// نظام الحفظ التلقائي (Auto-Save)
  /// ═══════════════════════════════════════════════════════════════

  void _initAutoSave() {
    _autoSaveTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _saveToBackup());
  }

  Future<void> _saveToBackup() async {
    if (_entries.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final backup = <String, dynamic>{
        'entries': _entries.map((e) => e.toJson()).toList(),
        'nextVerse': _nextVerse,
        'idCounter': _idCounter,
        'activeType': _activeType.name,
        'activePage': _activePage,
        'sourceFilePath': _sourceFilePath,
        'preloadedScript': _preloadedScript,
        'scriptIndex': _scriptIndex,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString('session_backup', jsonEncode(backup));
    } catch (error, stack) {
      AppLogger.instance.warn('خطأ في الحفظ التلقائي', error, stack);
    }
  }

  Future<void> _loadFromBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backup = prefs.getString('session_backup');
      if (backup == null) return;

      final data = jsonDecode(backup) as Map<String, dynamic>;
      final rawEntries = data['entries'] as List?;
      final loadedEntries = rawEntries
          ?.map((e) => TimingEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      if (loadedEntries != null && loadedEntries.isNotEmpty) {
        _entries.addAll(loadedEntries);
        _nextVerse = data['nextVerse'] as int? ?? loadedEntries.length + 1;
        _idCounter = data['idCounter'] as int? ?? loadedEntries.length;
        if (data['activeType'] != null) {
          _activeType =
              SegmentType.fromString(data['activeType'] as String?);
        }
        _activePage = data['activePage'] as int?;
        if (data['preloadedScript'] is List) {
          _preloadedScript.addAll(
            (data['preloadedScript'] as List).map((e) => e.toString()),
          );
          _scriptIndex = data['scriptIndex'] as int? ?? 0;
        }
        _sourceFilePath = data['sourceFilePath'] as String?;
        notifyListeners();
      }
    } catch (error, stack) {
      AppLogger.instance.warn('خطأ في استرجاع النسخة الاحتياطية', error, stack);
    }
  }

  Future<void> clearBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_backup');
    } catch (error, stack) {
      AppLogger.instance.warn('خطأ في حذف النسخة الاحتياطية', error, stack);
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// استيراد البيانات من ملف JSON
  /// ═══════════════════════════════════════════════════════════════

  Future<bool> importFromJsonFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _lastError = 'الملف غير موجود: $filePath';
        notifyListeners();
        return false;
      }

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      _importedLessonId = json['lesson_id'] as String? ?? json['lessonId'] as String?;
      _importedAudioUrl = json['audio_url'] as String? ?? json['audioUrl'] as String?;

      final rawList = (json['segments'] as List?) ?? (json['verses'] as List?);
      if (rawList == null || rawList.isEmpty) {
        _lastError = 'لا توجد بيانات أو مقاطع في الملف المستورد';
        notifyListeners();
        return false;
      }

      _entries.clear();
      int maxId = 0;
      for (final item in rawList) {
        final entry = TimingEntry.fromJson(item as Map<String, dynamic>);
        _entries.add(entry);
        maxId = math.max(maxId, entry.id);
      }

      _idCounter = maxId + 1;
      _nextVerse = _entries.length + 1;
      _lastError = null;
      AppLogger.instance.info('تم استيراد ${_entries.length} مقطع بنجاح');
      notifyListeners();
      return true;
    } catch (error, stack) {
      _lastError = 'خطأ في استيراد الملف: $error';
      AppLogger.instance.error('خطأ في استيراد الملف', error, stack);
      notifyListeners();
      return false;
    }
  }

  Future<String?> pickAndImportJsonFile() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(label: 'JSON', extensions: <String>['json']),
        ],
      );
      if (file == null) return null;

      final success = await importFromJsonFile(file.path);
      return success ? file.path : null;
    } catch (error, stack) {
      _lastError = 'خطأ في فتح الملف: $error';
      AppLogger.instance.error('خطأ في فتح ملف JSON', error, stack);
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    player.dispose();
    super.dispose();
  }
}

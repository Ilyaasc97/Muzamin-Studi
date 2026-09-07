import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_logger.dart';
import '../models/preloaded_script_item.dart';
import '../models/timing_entry.dart';
import '../services/audio_cache_service.dart';
import '../services/quran_api_service.dart';
import '../services/quran_font_service.dart';
import '../services/settings_service.dart';
import '../services/waveform_service.dart';

class SessionBackupInfo {
  const SessionBackupInfo({
    this.sourceFilePath,
    required this.fileName,
    required this.segmentCount,
    this.savedAt,
  });

  final String? sourceFilePath;
  final String fileName;
  final int segmentCount;
  final DateTime? savedAt;
}

class TimingSession extends ChangeNotifier {
  TimingSession({bool autoRestoreBackup = false}) {
    _latencyOffsetMs = SettingsService.instance.latencyOffsetMs;
    _initAutoSave();
    if (autoRestoreBackup) {
      restoreSessionFromBackup();
    }
  }

  Timer? _autoSaveTimer;

  final AudioPlayer player = AudioPlayer();

  static const List<double> speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  static const List<XTypeGroup> audioTypeGroups = <XTypeGroup>[
    XTypeGroup(
      label: 'ملفات صوتية',
      extensions: <String>['mp3', 'm4a', 'aac', 'wav', 'ogg', 'opus'],
    ),
  ];

  final List<TimingEntry> _entries = <TimingEntry>[];
  final List<PreloadedScriptItem> _preloadedScript = <PreloadedScriptItem>[];
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
  String? _loadingLabel;
  double? _downloadProgress;

  HttpClient? _activeDownloadClient;
  IOSink? _activeDownloadSink;
  File? _activeDownloadFile;
  bool _cancelRequested = false;

  int? _previewingEntryId;
  bool _previewLoop = false;
  StreamSubscription<Duration>? _previewSubscription;

  int? get previewingEntryId => _previewingEntryId;
  bool get isPreviewLoop => _previewLoop;

  String? _importedLessonId;
  String? _importedAudioUrl;

  List<TimingEntry> get entries => List<TimingEntry>.unmodifiable(_entries);
  List<String> get preloadedScript =>
      List<String>.unmodifiable(_preloadedScript.map((e) => e.text));
  List<PreloadedScriptItem> get preloadedScriptItems =>
      List<PreloadedScriptItem>.unmodifiable(_preloadedScript);
  int get scriptIndex => _scriptIndex;
  bool get hasPreloadedScript =>
      _preloadedScript.isNotEmpty && _scriptIndex < _preloadedScript.length;
  bool get canPrevScriptLine => _preloadedScript.isNotEmpty && _scriptIndex > 0;
  bool get canSkipScriptLine => hasPreloadedScript;
  int get totalScriptCount => _preloadedScript.length;
  int get currentScriptVerseIndex => _scriptIndex + 1;
  PreloadedScriptItem? get currentScriptItem =>
      hasPreloadedScript ? _preloadedScript[_scriptIndex] : null;
  String? get currentScriptLine => currentScriptItem?.text;
  int? get currentScriptPage => currentScriptItem?.page ?? _activePage;
  String get currentScriptFontFamily =>
      currentScriptItem?.fontFamily ??
      QuranFontService.getFontFamilyForPage(currentScriptPage);
  int? get currentScriptVerseNumber => currentScriptItem?.verseNumber ?? _nextVerse;
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
  String? get loadingLabel => _loadingLabel;
  double? get downloadProgress => _downloadProgress;
  bool get hasSource => _sourceFilePath != null;
  String? get sourceFileName =>
      _sourceFilePath == null ? null : p.basename(_sourceFilePath!);
  String? get importedLessonId => _importedLessonId;
  String? get importedAudioUrl => _importedAudioUrl;

  void cancelLoading() {
    _cancelRequested = true;
    try {
      _activeDownloadClient?.close(force: true);
    } catch (_) {}
    _activeDownloadClient = null;

    try {
      _activeDownloadSink?.close();
    } catch (_) {}
    _activeDownloadSink = null;

    if (_activeDownloadFile != null && _activeDownloadFile!.existsSync()) {
      try {
        _activeDownloadFile!.deleteSync();
      } catch (_) {}
    }
    _activeDownloadFile = null;

    try {
      player.stop();
    } catch (_) {}

    _loading = false;
    _loadingLabel = null;
    _downloadProgress = null;
    _lastError = 'errors.download_cancelled'.tr();
    notifyListeners();
  }

  void setActiveType(SegmentType type) {
    if (_activeType == type) return;
    _activeType = type;
    notifyListeners();
  }

  void setActivePage(int? page) {
    if (_activePage == page) return;
    _activePage = page;
    if (page != null) {
      QuranFontService.instance.ensurePageFontLoaded(page);
    }
    notifyListeners();
  }

  void incrementPage() {
    _activePage = (_activePage ?? 0) + 1;
    if (_activePage != null) {
      QuranFontService.instance.ensurePageFontLoaded(_activePage!);
    }
    notifyListeners();
  }

  void decrementPage() {
    if (_activePage != null && _activePage! > 1) {
      _activePage = _activePage! - 1;
      QuranFontService.instance.ensurePageFontLoaded(_activePage!);
      notifyListeners();
    }
  }

  void setNextVerse(int num) {
    _nextVerse = math.max(1, num);
    notifyListeners();
  }

  void _syncCurrentScriptState() {
    if (hasPreloadedScript) {
      final item = _preloadedScript[_scriptIndex];
      if (item.page != null) {
        _activePage = item.page;
        QuranFontService.instance.ensurePageFontLoaded(item.page!);
      }
      if (item.verseNumber != null) {
        _nextVerse = item.verseNumber!;
      }
      if (item.segmentType != null) {
        _activeType = item.segmentType!;
      }
    }
  }

  void setPreloadedVerses(List<FetchedVerse> verses) {
    _preloadedScript.clear();
    for (final v in verses) {
      _preloadedScript.add(PreloadedScriptItem.fromFetchedVerse(v));
      if (v.page != null) {
        QuranFontService.instance.ensurePageFontLoaded(v.page!);
      }
    }
    _scriptIndex = 0;
    _syncCurrentScriptState();
    AppLogger.instance.info('تم تحميل ${_preloadedScript.length} آية للتلقيم التلقائي');
    notifyListeners();
  }

  void setPreloadedScript(List<String> lines) {
    _preloadedScript.clear();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        _preloadedScript.add(PreloadedScriptItem(text: trimmed));
      }
    }
    _scriptIndex = 0;
    _syncCurrentScriptState();
    AppLogger.instance.info('تم تحميل ${_preloadedScript.length} نصاً للتلقيم التلقائي');
    notifyListeners();
  }

  void setPreloadedItems(List<PreloadedScriptItem> items) {
    _preloadedScript.clear();
    _preloadedScript.addAll(items);
    _scriptIndex = 0;
    _syncCurrentScriptState();
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
      _syncCurrentScriptState();
      notifyListeners();
    }
  }

  void skipScriptLine() {
    if (hasPreloadedScript) {
      _scriptIndex++;
      _syncCurrentScriptState();
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
      _lastError = 'errors.invalid_url'.tr();
      notifyListeners();
      return null;
    }

    final String name = p.basename(uri.path);
    final String label = name.isNotEmpty ? name : 'remote_audio.mp3';
    final String lessonId = generateLessonIdFromPath(name.isEmpty ? url : name);

    _cancelRequested = false;
    _loading = true;
    _loadingLabel = label;
    _downloadProgress = null;
    _lastError = null;
    notifyListeners();

    File? tempFile;
    try {
      final Directory dir = await AudioCacheService.instance.getCacheDirectory();
      final String cacheDir = dir.path;

      final String ext = p.extension(name).isNotEmpty ? p.extension(name) : '.mp3';
      final String sanitized = name.replaceAll(RegExp(r'[^a-zA-Z0-9_\.\-]'), '_');
      final String safeName = sanitized.isEmpty ? 'audio$ext' : sanitized;
      final String targetPath = p.join(
        cacheDir,
        '${DateTime.now().millisecondsSinceEpoch}_$safeName',
      );
      tempFile = File(targetPath);
      _activeDownloadFile = tempFile;

      final HttpClient client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      _activeDownloadClient = client;

      final HttpClientRequest request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 5;

      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('errors.timeout'.tr());
        },
      );

      if (_cancelRequested) {
        throw Exception('Download cancelled by user');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      final int totalBytes = response.contentLength;
      int receivedBytes = 0;
      final IOSink sink = tempFile.openWrite();
      _activeDownloadSink = sink;

      await for (final List<int> chunk in response) {
        if (_cancelRequested) {
          throw Exception('Download cancelled by user');
        }
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final double progress = receivedBytes / totalBytes;
          if (_downloadProgress == null ||
              (progress - _downloadProgress!).abs() >= 0.02 ||
              progress >= 1.0) {
            _downloadProgress = progress;
            notifyListeners();
          }
        }
      }

      await sink.flush();
      await sink.close();
      _activeDownloadSink = null;

      if (_cancelRequested) {
        throw Exception('Download cancelled by user');
      }

      await _loadAudio(
        () => player.setFilePath(tempFile!.path),
        label: label,
        filePath: tempFile.path,
      );

      return lessonId;
    } catch (error, stack) {
      if (_cancelRequested) {
        _lastError = 'errors.download_cancelled'.tr();
        AppLogger.instance.info('تم إلغاء تحميل الملف بواسطة المستخدم');
      } else {
        _lastError = '${'errors.load_failed'.tr()}: $error';
        AppLogger.instance.error('فشل تحميل الملف الصوتي من الرابط', error, stack);
      }
      if (tempFile != null && tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }
      return null;
    } finally {
      _activeDownloadClient?.close(force: true);
      _activeDownloadClient = null;
      _activeDownloadSink = null;
      _activeDownloadFile = null;
      _loading = false;
      _loadingLabel = null;
      _downloadProgress = null;
      notifyListeners();
    }
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
    _loadingLabel = label;
    _lastError = null;
    notifyListeners();
    try {
      await load().timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          throw TimeoutException('errors.timeout'.tr());
        },
      );
      if (_cancelRequested) {
        throw Exception('Audio loading cancelled by user');
      }
      _sourceFilePath = filePath ?? label;
      _resetEntries();
      if (filePath != null) {
        await WaveformService.instance.generateFromFile(filePath);
      } else {
        await WaveformService.instance.generateFallback();
      }
      AppLogger.instance.info('تم تحميل الملف الصوتي بنجاح: $label');
    } catch (error, stack) {
      if (_cancelRequested) {
        _lastError = 'errors.download_cancelled'.tr();
      } else {
        _lastError = '${'errors.load_failed'.tr()}: $error';
      }
      AppLogger.instance.error('فشل تحميل الملف الصوتي', error, stack);
    } finally {
      _loading = false;
      _loadingLabel = null;
      notifyListeners();
    }
  }

  void togglePreviewLoop() {
    _previewLoop = !_previewLoop;
    notifyListeners();
  }

  void stopPreview() {
    _previewSubscription?.cancel();
    _previewSubscription = null;
    _previewingEntryId = null;
    notifyListeners();
  }

  Future<void> playEntryPreview(TimingEntry entry) async {
    if (_sourceFilePath == null) return;

    // إذا كان المقطع نفسه قيد المعاينة ويعمل، نوقفه
    if (_previewingEntryId == entry.id && player.playing) {
      _previewSubscription?.cancel();
      _previewSubscription = null;
      _previewingEntryId = null;
      await player.pause();
      notifyListeners();
      return;
    }

    _previewSubscription?.cancel();
    _previewingEntryId = entry.id;
    notifyListeners();

    await player.seek(Duration(milliseconds: entry.startMs));
    if (!player.playing) {
      await player.play();
    }

    _previewSubscription = player.positionStream.listen((pos) async {
      if (pos.inMilliseconds >= entry.endMs) {
        if (_previewLoop) {
          await player.seek(Duration(milliseconds: entry.startMs));
        } else {
          _previewSubscription?.cancel();
          _previewSubscription = null;
          _previewingEntryId = null;
          await player.pause();
          notifyListeners();
        }
      }
    });
  }

  Future<void> togglePlayPause() async {
    if (_sourceFilePath == null) return;
    _previewSubscription?.cancel();
    _previewSubscription = null;
    _previewingEntryId = null;
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
    _previewSubscription?.cancel();
    _previewSubscription = null;
    _previewingEntryId = null;
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

      _entries.add(_buildEntry(start, end));
      _pendingStartMs = null;
    }
    notifyListeners();
  }

  TimingEntry _buildEntry(int startMs, int endMs) {
    String? attachedText;
    int entryVerse = _nextVerse;
    int? entryPage = _activePage;
    SegmentType entryType = _activeType;

    String? surahName;

    if (hasPreloadedScript) {
      final item = _preloadedScript[_scriptIndex++];
      attachedText = item.text;
      if (item.verseNumber != null) entryVerse = item.verseNumber!;
      if (item.page != null) entryPage = item.page;
      if (item.segmentType != null) entryType = item.segmentType!;
      surahName = item.surahName;
      _syncCurrentScriptState();
    } else {
      _nextVerse++;
    }

    String? label;
    if (attachedText != null && entryType != SegmentType.quran) {
      label = attachedText;
    } else if (entryType == SegmentType.quran) {
      final surah = surahName ??
          QuranApiService.instance.getSurahNameForAyah(
            page: entryPage,
            ayah: entryVerse,
          );
      if (surah != null && surah.isNotEmpty) {
        label = '$surah ($entryVerse)';
      }
    }

    final String? textArabic = attachedText != null && entryType == SegmentType.quran
        ? attachedText
        : null;

    return TimingEntry(
      id: _idCounter++,
      verseNumber: entryVerse,
      type: entryType,
      page: entryPage,
      startMs: startMs,
      endMs: endMs,
      label: label,
      textArabic: textArabic,
    );
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

      _entries.add(_buildEntry(start, end));
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
      _syncCurrentScriptState();
    } else {
      _renumberFromListOrder();
    }
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
        'preloadedScript': _preloadedScript.map((e) => e.toJson()).toList(),
        'scriptIndex': _scriptIndex,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString('session_backup', jsonEncode(backup));
    } catch (error, stack) {
      AppLogger.instance.warn('خطأ في الحفظ التلقائي', error, stack);
    }
  }

  static Future<SessionBackupInfo?> checkPreviousBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backup = prefs.getString('session_backup');
      if (backup == null) return null;

      final data = jsonDecode(backup) as Map<String, dynamic>;
      final rawEntries = data['entries'] as List?;
      if (rawEntries == null || rawEntries.isEmpty) return null;

      final sourcePath = data['sourceFilePath'] as String?;
      final String fileName;
      if (sourcePath != null && sourcePath.isNotEmpty) {
        fileName = p.basename(sourcePath);
      } else {
        fileName = 'export.verses_ready'.tr();
      }

      DateTime? savedAt;
      if (data['savedAt'] is String) {
        savedAt = DateTime.tryParse(data['savedAt'] as String);
      }

      return SessionBackupInfo(
        sourceFilePath: sourcePath,
        fileName: fileName,
        segmentCount: rawEntries.length,
        savedAt: savedAt,
      );
    } catch (e, stack) {
      AppLogger.instance.warn('خطأ في فحص النسخة الاحتياطية', e, stack);
      return null;
    }
  }

  Future<String?> restoreSessionFromBackup({bool reloadAudio = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backup = prefs.getString('session_backup');
      if (backup == null) return null;

      final data = jsonDecode(backup) as Map<String, dynamic>;
      final rawEntries = data['entries'] as List?;
      final loadedEntries = rawEntries
          ?.map((e) => TimingEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      if (loadedEntries == null || loadedEntries.isEmpty) return null;

      _entries.clear();
      _entries.addAll(loadedEntries);
      _nextVerse = data['nextVerse'] as int? ?? loadedEntries.length + 1;
      _idCounter = data['idCounter'] as int? ?? loadedEntries.length;
      if (data['activeType'] != null) {
        _activeType =
            SegmentType.fromString(data['activeType'] as String?);
      }
      _activePage = data['activePage'] as int?;
      if (data['preloadedScript'] is List) {
        _preloadedScript.clear();
        _preloadedScript.addAll(
          (data['preloadedScript'] as List)
              .map((e) => PreloadedScriptItem.fromJson(e)),
        );
        _scriptIndex = data['scriptIndex'] as int? ?? 0;
        _syncCurrentScriptState();
      }

      final savedPath = data['sourceFilePath'] as String?;
      String? lessonId;

      if (reloadAudio && savedPath != null && savedPath.isNotEmpty) {
        if (File(savedPath).existsSync()) {
          lessonId = await loadLocalFile(savedPath);
        } else if (savedPath.startsWith('http://') || savedPath.startsWith('https://')) {
          lessonId = await loadRemoteUrl(savedPath);
        } else {
          _sourceFilePath = savedPath;
        }
      } else if (savedPath != null) {
        _sourceFilePath = savedPath;
      }

      notifyListeners();
      AppLogger.instance.info('تم استرجاع ${_entries.length} مقطعاً من الجلسة السابقة');
      return lessonId ?? (savedPath != null ? generateLessonIdFromPath(savedPath) : null);
    } catch (error, stack) {
      AppLogger.instance.error('خطأ في استرجاع النسخة الاحتياطية', error, stack);
      return null;
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
        _lastError = 'errors.file_not_found'.tr(namedArgs: {'path': filePath});
        notifyListeners();
        return false;
      }

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      _importedLessonId = json['lesson_id'] as String? ?? json['lessonId'] as String?;
      _importedAudioUrl = json['audio_url'] as String? ?? json['audioUrl'] as String?;

      final rawList = (json['segments'] as List?) ?? (json['verses'] as List?);
      if (rawList == null || rawList.isEmpty) {
        _lastError = 'import.no_verses'.tr();
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
      _lastError = '${'import.import_error'.tr()}: $error';
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
      _lastError = '${'errors.load_failed'.tr()}: $error';
      AppLogger.instance.error('خطأ في فتح ملف JSON', error, stack);
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    _previewSubscription?.cancel();
    _autoSaveTimer?.cancel();
    cancelLoading();
    player.dispose();
    super.dispose();
  }
}

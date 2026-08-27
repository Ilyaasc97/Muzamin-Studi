import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

import '../controllers/timing_session.dart';
import '../models/timing_entry.dart';
import '../widgets/entries_list.dart';
import '../widgets/export_bar.dart';
import '../widgets/language_selector.dart';
import '../widgets/player_panel.dart';
import '../widgets/record_button.dart';
import '../widgets/session_metadata_card.dart';
import '../widgets/type_selector_chips.dart';
import '../widgets/user_guide_dialog.dart';
import '../services/json_export_service.dart';
import '../services/settings_service.dart';
import '../screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TimingSession _session = TimingSession();
  final JsonExportService _exportService = JsonExportService();
  final SettingsService _settings = SettingsService.instance;
  final TextEditingController _lessonIdController = TextEditingController();
  final TextEditingController _audioUrlController = TextEditingController();
  final FocusNode _rootFocus = FocusNode(debugLabel: 'root-shortcuts');
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  @override
  void dispose() {
    _session.dispose();
    _lessonIdController.dispose();
    _audioUrlController.dispose();
    _rootFocus.dispose();
    super.dispose();
  }

  void _keepShortcutsAlive() {
    _rootFocus.requestFocus();
  }

  Future<void> _togglePlayPause() async {
    await _session.togglePlayPause();
    _keepShortcutsAlive();
  }

  void _mark() {
    _session.toggleMark();
    _keepShortcutsAlive();
  }

  void _cancelPending() {
    _session.cancelPendingStart();
    _keepShortcutsAlive();
  }

  void _seekRelative(int deltaMs) {
    _session.seekRelative(deltaMs);
    _keepShortcutsAlive();
  }

  void _undo() {
    _session.undoLast();
    _keepShortcutsAlive();
  }

  Future<void> _confirmClearAll() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('dialog.delete_all_question'.tr()),
        content: Text('dialog.delete_all_warning'.tr()),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('dialog.delete_all'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _session.clearAll();
    }
    _keepShortcutsAlive();
  }

  Future<void> _export() async {
    if (_session.entries.isEmpty) {
      _showSnack('export.no_timestamps_to_export'.tr());
      return;
    }
    if (_lessonIdController.text.trim().isEmpty) {
      _showSnack('export.enter_lesson_id'.tr(), isError: true);
      return;
    }
    setState(() => _exporting = true);
    try {
      final result = await _exportService.export(
        lessonId: _lessonIdController.text,
        audioUrl: _audioUrlController.text,
        sourceFilePath: _session.sourceFilePath,
        entries: _session.entries,
      );
      if (!mounted || result == null) return;
      _showSnack(
        'export.export_success'
            .tr(namedArgs: {'count': result.segmentCount.toString()}),
      );
      await _session.clearBackup();
    } catch (error) {
      if (mounted) {
        _showSnack('${'export.export_failed'.tr()}: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
      _keepShortcutsAlive();
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  SingleActivator _createActivator(String keyString) {
    final parts = keyString.split('+');
    final rawKey = parts.last.trim();
    final normalizedKey = rawKey.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final key = _lookupLogicalKey(normalizedKey);
    return SingleActivator(
      key,
      control: parts.contains('Control'),
      shift: parts.contains('Shift'),
      alt: parts.contains('Alt'),
      meta: parts.contains('Meta'),
    );
  }

  LogicalKeyboardKey _lookupLogicalKey(String normalizedKey) {
    const keyMap = <String, LogicalKeyboardKey>{
      'space': LogicalKeyboardKey.space,
      'enter': LogicalKeyboardKey.enter,
      'numpadenter': LogicalKeyboardKey.numpadEnter,
      'numenter': LogicalKeyboardKey.numpadEnter,
      'return': LogicalKeyboardKey.enter,
      'escape': LogicalKeyboardKey.escape,
      'esc': LogicalKeyboardKey.escape,
      'arrowright': LogicalKeyboardKey.arrowRight,
      'arrowleft': LogicalKeyboardKey.arrowLeft,
      'arrowup': LogicalKeyboardKey.arrowUp,
      'arrowdown': LogicalKeyboardKey.arrowDown,
      'control': LogicalKeyboardKey.control,
      'ctrl': LogicalKeyboardKey.control,
      'shift': LogicalKeyboardKey.shift,
      'alt': LogicalKeyboardKey.alt,
      'meta': LogicalKeyboardKey.meta,
      'delete': LogicalKeyboardKey.delete,
      'del': LogicalKeyboardKey.delete,
      'z': LogicalKeyboardKey.keyZ,
      'x': LogicalKeyboardKey.keyX,
      'c': LogicalKeyboardKey.keyC,
      'v': LogicalKeyboardKey.keyV,
      's': LogicalKeyboardKey.keyS,
      'e': LogicalKeyboardKey.keyE,
      'm': LogicalKeyboardKey.keyM,
      'tab': LogicalKeyboardKey.tab,
      'backspace': LogicalKeyboardKey.backspace,
      'home': LogicalKeyboardKey.home,
      'end': LogicalKeyboardKey.end,
      'pageup': LogicalKeyboardKey.pageUp,
      'pagedown': LogicalKeyboardKey.pageDown,
    };
    return keyMap[normalizedKey] ?? LogicalKeyboardKey.space;
  }

  Map<ShortcutActivator, VoidCallback> _buildShortcuts() {
    return {
      _createActivator(_settings.shortcuts['play_pause'] ?? 'Space'):
          _togglePlayPause,
      _createActivator(_settings.shortcuts['mark_verse'] ?? 'Enter'): _mark,
      _createActivator(_settings.shortcuts['mark_verse'] ?? 'NumpadEnter'):
          _mark,
      _createActivator(_settings.shortcuts['cancel_pending'] ?? 'Escape'):
          _cancelPending,
      _createActivator(_settings.shortcuts['seek_forward_5s'] ?? 'ArrowRight'):
          () => _seekRelative(5000),
      _createActivator(_settings.shortcuts['seek_backward_5s'] ?? 'ArrowLeft'):
          () => _seekRelative(-5000),
      _createActivator(_settings.shortcuts['seek_forward_30s'] ?? 'ArrowUp'):
          () => _seekRelative(30000),
      _createActivator(_settings.shortcuts['seek_backward_30s'] ?? 'ArrowDown'):
          () => _seekRelative(-30000),
      _createActivator(_settings.shortcuts['undo'] ?? 'Control+Z'): _undo,

      // اختصارات التبديل السريع لأنواع المقاطع
      const SingleActivator(LogicalKeyboardKey.digit1): () =>
          _session.setActiveType(SegmentType.quran),
      const SingleActivator(LogicalKeyboardKey.digit2): () =>
          _session.setActiveType(SegmentType.hadith),
      const SingleActivator(LogicalKeyboardKey.digit3): () =>
          _session.setActiveType(SegmentType.chapter),
      const SingleActivator(LogicalKeyboardKey.digit4): () =>
          _session.setActiveType(SegmentType.dhikr),
      const SingleActivator(LogicalKeyboardKey.digit5): () =>
          _session.setActiveType(SegmentType.custom),
      const SingleActivator(LogicalKeyboardKey.numpad1): () =>
          _session.setActiveType(SegmentType.quran),
      const SingleActivator(LogicalKeyboardKey.numpad2): () =>
          _session.setActiveType(SegmentType.hadith),
      const SingleActivator(LogicalKeyboardKey.numpad3): () =>
          _session.setActiveType(SegmentType.chapter),
      const SingleActivator(LogicalKeyboardKey.numpad4): () =>
          _session.setActiveType(SegmentType.dhikr),
      const SingleActivator(LogicalKeyboardKey.numpad5): () =>
          _session.setActiveType(SegmentType.custom),
    };
  }

  Future<void> _initializeSettings() async {
    await _settings.initialize();
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (await UserGuideDialog.shouldShowOnStartup() && mounted) {
          UserGuideDialog.show(context, isFirstLaunch: true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: isLight ? 0.7 : 0.4),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/icons/app_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      size: 22,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'app_title'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                        color: scheme.onSurface,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: isLight ? 0.12 : 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'STUDIO',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'app_subtitle'.tr(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          // زر الدليل الترحيبي والتعليمات
          IconButton.filledTonal(
            tooltip: 'guide.dialog_title'.tr(),
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => UserGuideDialog.show(context),
            icon: Icon(Icons.help_outline_rounded, size: 19, color: scheme.primary),
          ),
          const SizedBox(width: 6),

          // زر التبديل السريع بين الوضعين النهاري والليلي
          IconButton.filledTonal(
            tooltip: 'تبديل الوضع (Dark / Light)',
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final newMode = Theme.of(context).brightness == Brightness.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
              SettingsService.instance.setThemeMode(newMode);
            },
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              size: 19,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 6),

          // زر الإعدادات
          IconButton.filledTonal(
            tooltip: 'common.settings'.tr(),
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: Icon(Icons.settings_outlined, size: 19, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 6),

          // محدد اللغة
          const LanguageSelector(),
          const SizedBox(width: 12),
        ],
      ),
      body: CallbackShortcuts(
        bindings: _buildShortcuts(),
        child: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          child: Column(
            children: [
              // الشريط العلوي للأستوديو
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: SessionMetadataCard(
                  session: _session,
                  lessonIdController: _lessonIdController,
                  audioUrlController: _audioUrlController,
                ),
              ),

              // منطقة العمل الرئيسية (متجاوبة)
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool wide = constraints.maxWidth >= 940;
                    return wide
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                // لوحة التحكم الصوتية والتسجيل
                                Expanded(
                                  flex: 6,
                                  child: _buildControlPanel(),
                                ),
                                const SizedBox(width: 12),
                                // قائمة الآيات المسجلة
                                Expanded(
                                  flex: 5,
                                  child: _buildEntriesPanel(),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: <Widget>[
                              Expanded(flex: 5, child: _buildControlPanel()),
                              const Divider(height: 1),
                              Expanded(flex: 5, child: _buildEntriesPanel()),
                            ],
                          );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TypeSelectorChips(session: _session),
          const SizedBox(height: 10),
          PlayerPanel(session: _session),
          const SizedBox(height: 12),
          RecordButton(session: _session, onPressed: _mark),
        ],
      ),
    );
  }

  Widget _buildEntriesPanel() {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ListenableBuilder(
              listenable: _session,
              builder: (BuildContext context, Widget? _) {
                return Row(
                  children: <Widget>[
                    Icon(
                      Icons.format_list_numbered_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${'entries.recorded_timestamps'.tr()} (${_session.entries.length})',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'entries.undo_tooltip'.tr(),
                      onPressed: _session.entries.isEmpty ? null : _undo,
                      icon: const Icon(Icons.undo_rounded, size: 20),
                    ),
                    IconButton(
                      tooltip: 'entries.delete_all_tooltip'.tr(),
                      onPressed:
                          _session.entries.isEmpty ? null : _confirmClearAll,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(child: EntriesList(session: _session)),
          ExportBar(
            session: _session,
            exporting: _exporting,
            onExport: _export,
            lessonId: _lessonIdController.text,
            audioUrl: _audioUrlController.text,
          ),
        ],
      ),
    );
  }
}

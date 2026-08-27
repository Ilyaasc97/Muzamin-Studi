import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../controllers/timing_session.dart';
import '../services/settings_service.dart';
import 'preload_script_dialog.dart';
import 'quran_fetch_dialog.dart';

class SessionMetadataCard extends StatefulWidget {
  const SessionMetadataCard({
    super.key,
    required this.session,
    required this.lessonIdController,
    required this.audioUrlController,
  });

  final TimingSession session;
  final TextEditingController lessonIdController;
  final TextEditingController audioUrlController;

  @override
  State<SessionMetadataCard> createState() => _SessionMetadataCardState();
}

class _SessionMetadataCardState extends State<SessionMetadataCard> {
  Future<void> _pickAudioFile() async {
    final lessonId = await widget.session.pickAndLoadAudio();
    if (lessonId != null && lessonId.isNotEmpty) {
      widget.lessonIdController.text = lessonId;
    }
  }

  Future<void> _showQuranFetchDialog() async {
    final count = await showDialog<int>(
      context: context,
      builder: (_) => QuranFetchDialog(session: widget.session),
    );
    if (count != null && count > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('quran.loaded_success'.tr(namedArgs: {'count': count.toString()})),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _importJson() async {
    final path = await widget.session.pickAndImportJsonFile();
    if (!mounted || path == null) return;
    if (widget.session.importedLessonId != null && widget.session.importedLessonId!.isNotEmpty) {
      widget.lessonIdController.text = widget.session.importedLessonId!;
    }
    if (widget.session.importedAudioUrl != null && widget.session.importedAudioUrl!.isNotEmpty) {
      widget.audioUrlController.text = widget.session.importedAudioUrl!;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'import.import_success'
              .tr(namedArgs: {'count': widget.session.entries.length.toString()}),
        ),
      ),
    );
  }

  void _showPreloadScriptDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => PreloadScriptDialog(session: widget.session),
    );
  }

  void _showUrlDialog() {
    final textController = TextEditingController(text: widget.audioUrlController.text);
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.link_rounded),
            const SizedBox(width: 8),
            Text('file.load_from_url'.tr()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              keyboardType: TextInputType.url,
              textDirection: ui.TextDirection.ltr,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'export.audio_url'.tr(),
                hintText: 'export.audio_url_hint'.tr(),
                prefixIcon: const Icon(Icons.cloud_download_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              final url = textController.text.trim();
              if (url.isNotEmpty) {
                widget.audioUrlController.text = url;
                Navigator.pop(ctx);
                final lessonId = await widget.session.loadRemoteUrl(url);
                if (lessonId != null && lessonId.isNotEmpty) {
                  widget.lessonIdController.text = lessonId;
                }
              }
            },
            child: Text('common.import'.tr()),
          ),
        ],
      ),
    );
  }

  void _showShortcutsDialog() {
    final settings = SettingsService.instance;
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.keyboard_rounded),
            const SizedBox(width: 8),
            Text('settings.shortcuts_title'.tr()),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: SettingsService.shortcutKeys.map((action) {
                final currentKey = settings.shortcuts[action] ??
                    settings.defaultShortcuts[action] ??
                    '';
                final actionKey = SettingsService.getActionKey(action);
                final fallback = SettingsService.shortcutLabels[action] ?? action;
                final label = actionKey.tr() != actionKey ? actionKey.tr() : fallback;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          settings.formatKeyForDisplay(currentKey),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: ListenableBuilder(
          listenable: widget.session,
          builder: (BuildContext context, Widget? _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    // زر فتح الملف والاستيراد وتلقيم النصوص
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.icon(
                          onPressed: widget.session.loading ? null : _pickAudioFile,
                          icon: const Icon(Icons.folder_open_rounded, size: 18),
                          label: Text('file.open_audio'.tr()),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: widget.session.loading ? null : _importJson,
                          icon: const Icon(Icons.file_open_outlined, size: 16),
                          label: Text('file.import_json'.tr()),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: _showQuranFetchDialog,
                          icon: const Icon(Icons.cloud_download_rounded, size: 16),
                          label: Text('quran.fetch_btn_short'.tr()),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: _showPreloadScriptDialog,
                          icon: const Icon(Icons.playlist_add_rounded, size: 16),
                          label: Text('script.preload_btn'.tr()),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'file.load_from_url'.tr(),
                          onPressed: widget.session.loading ? null : _showUrlDialog,
                          icon: const Icon(Icons.link_rounded, size: 20),
                        ),
                      ],
                    ),

                    // شارة الملف الصوتي المفتوح
                    Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.session.hasSource
                              ? scheme.primary.withValues(alpha: 0.5)
                              : scheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.session.loading)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              widget.session.hasSource
                                  ? Icons.graphic_eq_rounded
                                  : Icons.audio_file_outlined,
                              size: 16,
                              color: widget.session.hasSource
                                  ? scheme.primary
                                  : Theme.of(context).hintColor,
                            ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: Text(
                              widget.session.sourceFileName ?? 'file.no_file_selected'.tr(),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: widget.session.hasSource
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: widget.session.hasSource ? null : Theme.of(context).hintColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // حقل معرّف الدرس وزر الاختصارات
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 170,
                          height: 38,
                          child: TextField(
                            controller: widget.lessonIdController,
                            textDirection: ui.TextDirection.ltr,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'export.lesson_id'.tr(),
                              hintText: 'export.lesson_id_hint'.tr(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              isDense: true,
                              prefixIcon: const Icon(Icons.badge_outlined, size: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'settings.shortcuts_title'.tr(),
                          onPressed: _showShortcutsDialog,
                          icon: const Icon(Icons.keyboard_rounded, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),

                // شريط إشعار النصوص الملقمة إن وجدت
                if (widget.session.hasPreloadedScript) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // شريط العنوان والتحكم
                        Row(
                          children: [
                            Icon(Icons.auto_stories_rounded, size: 16, color: scheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'script.current_next'.tr(),
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.session.currentScriptItem?.surahName != null ||
                                widget.session.currentScriptItem?.page != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: scheme.primary.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  [
                                    if (widget.session.currentScriptItem?.surahName != null)
                                      '${widget.session.currentScriptItem!.surahName} (${widget.session.currentScriptItem!.verseNumber})',
                                    if (widget.session.currentScriptItem?.page != null)
                                      '${'edit.page'.tr()} ${widget.session.currentScriptItem!.page}',
                                  ].join(' • '),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'script.progress'.tr(namedArgs: {
                                  'current': widget.session.currentScriptVerseIndex.toString(),
                                  'total': widget.session.totalScriptCount.toString(),
                                }),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: 'script.prev'.tr(),
                              onPressed: widget.session.canPrevScriptLine
                                  ? () => widget.session.prevScriptLine()
                                  : null,
                              icon: const Icon(Icons.skip_previous_rounded, size: 18),
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              tooltip: 'script.skip'.tr(),
                              onPressed: widget.session.canSkipScriptLine
                                  ? () => widget.session.skipScriptLine()
                                  : null,
                              icon: const Icon(Icons.skip_next_rounded, size: 18),
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              tooltip: 'script.clear'.tr(),
                              onPressed: () => widget.session.clearPreloadedScript(),
                              icon: Icon(Icons.close_rounded, size: 16, color: scheme.error),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // نص الآية موسّط بخط مصحف المدينة
                        Text(
                          widget.session.currentScriptLine ?? '',
                          textAlign: TextAlign.center,
                          textDirection: ui.TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: widget.session.currentScriptFontFamily,
                            fontSize: 22,
                            height: 1.8,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
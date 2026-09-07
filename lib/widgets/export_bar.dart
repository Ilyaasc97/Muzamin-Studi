import 'dart:async';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../controllers/timing_session.dart';
import '../models/timing_entry.dart';
import '../services/multi_format_export_service.dart';

class ExportBar extends StatefulWidget {
  const ExportBar({
    super.key,
    required this.session,
    required this.exporting,
    required this.onExport,
    required this.lessonId,
    required this.audioUrl,
  });

  final TimingSession session;
  final bool exporting;
  final Future<bool> Function() onExport;
  final String lessonId;
  final String audioUrl;

  @override
  State<ExportBar> createState() => _ExportBarState();
}

class _ExportBarState extends State<ExportBar> {
  bool _showSuccess = false;
  Timer? _successTimer;

  @override
  void dispose() {
    _successTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleExport() async {
    final success = await widget.onExport();
    if (success && mounted) {
      setState(() => _showSuccess = true);
      _successTimer?.cancel();
      _successTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showSuccess = false);
      });
    }
  }

  Future<void> _exportOtherFormat(
    BuildContext context,
    ExportFormat format,
  ) async {
    if (format == ExportFormat.json) {
      await _handleExport();
      return;
    }

    // التحقق من وجود lessonId قبل التصدير
    if (widget.lessonId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('export.enter_lesson_id'.tr()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    try {
      final path =
          await MultiFormatExportService.instance.exportFormattedFile(
        format: format,
        lessonId: widget.lessonId,
        audioUrl: widget.audioUrl,
        sourceFilePath: widget.session.sourceFilePath,
        entries: widget.session.entries,
      );
      if (path != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'export.export_success_path'.tr(namedArgs: {'path': path}),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'export.export_failed'.tr()} $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: ListenableBuilder(
        listenable: widget.session,
        builder: (context, _) {
          final count = widget.session.entries.length;
          final lastEndMs = widget.session.entries.isNotEmpty
              ? widget.session.entries.last.endMs
              : 0;

          return Row(
            children: [
              // إحصائيات الجلسة
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.layers_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'export.segments_ready'.tr(
                        namedArgs: {'count': count.toString()},
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        TimingEntry.formatTime(lastEndMs),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // خيارات التصدير الأخرى للمطورين
              PopupMenuButton<ExportFormat>(
                tooltip: 'export_formats.title'.tr(),
                enabled: !widget.exporting && widget.session.entries.isNotEmpty,
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (format) => _exportOtherFormat(context, format),
                itemBuilder: (context) => [
                  // 1. حزمة المطورين البرمجية (Developer Suite)
                  PopupMenuItem(
                    value: ExportFormat.json,
                    child: Row(
                      children: [
                        const Icon(Icons.data_object_rounded, size: 18, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text('export_formats.json'.tr()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: ExportFormat.dart,
                    child: Row(
                      children: [
                        const Icon(Icons.code_rounded, size: 18, color: Color(0xFF60A5FA)),
                        const SizedBox(width: 8),
                        Text('export_formats.dart'.tr()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: ExportFormat.flutterPlayer,
                    child: Row(
                      children: [
                        const Icon(Icons.widgets_rounded, size: 18, color: Color(0xFFA78BFA)),
                        const SizedBox(width: 8),
                        Text('export_formats.flutter_player'.tr()),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),

                  // 2. صيغ الترجمة والتفريغ الصوتي (Subtitles & Transcription)
                  PopupMenuItem(
                    value: ExportFormat.vtt,
                    child: Row(
                      children: [
                        const Icon(Icons.subtitles_rounded, size: 18, color: Color(0xFF2DD4BF)),
                        const SizedBox(width: 8),
                        Text('export_formats.vtt'.tr()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: ExportFormat.srt,
                    child: Row(
                      children: [
                        const Icon(Icons.closed_caption_rounded, size: 18, color: Color(0xFFFBBF24)),
                        const SizedBox(width: 8),
                        Text('export_formats.srt'.tr()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: ExportFormat.audacity,
                    child: Row(
                      children: [
                        const Icon(Icons.graphic_eq_rounded, size: 18, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 8),
                        Text('export_formats.audacity'.tr()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: ExportFormat.csv,
                    child: Row(
                      children: [
                        const Icon(Icons.table_chart_rounded, size: 18, color: Color(0xFF34D399)),
                        const SizedBox(width: 8),
                        Text('export_formats.csv'.tr()),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),

                  // 3. مستوى كامل المشروع (Project-level Manifest)
                  PopupMenuItem(
                    value: ExportFormat.manifest,
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_rounded, size: 18, color: Color(0xFFEC4899)),
                        const SizedBox(width: 8),
                        Text('export_formats.manifest'.tr()),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),

              // زر التصدير الرئيسي (JSON) مع تأكيد بصري بعد النجاح
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: FilledButton.icon(
                  onPressed: (widget.exporting || widget.session.entries.isEmpty || _showSuccess)
                      ? null
                      : _handleExport,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    backgroundColor: _showSuccess ? Colors.green.shade600 : null,
                    disabledBackgroundColor: _showSuccess
                        ? Colors.green.shade600.withValues(alpha: 0.85)
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: widget.exporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _showSuccess
                          ? const Icon(Icons.check_circle_rounded, size: 18)
                          : const Icon(Icons.ios_share_rounded, size: 18),
                  label: Text(
                    _showSuccess ? 'common.success'.tr() : 'export.export_json_btn'.tr(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

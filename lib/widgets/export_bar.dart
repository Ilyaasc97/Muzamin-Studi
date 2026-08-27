import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../controllers/timing_session.dart';
import '../models/timing_entry.dart';
import '../services/multi_format_export_service.dart';

class ExportBar extends StatelessWidget {
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
  final Future<void> Function() onExport;
  final String lessonId;
  final String audioUrl;

  Future<void> _exportOtherFormat(
    BuildContext context,
    ExportFormat format,
  ) async {
    try {
      final path =
          await MultiFormatExportService.instance.exportFormattedFile(
        format: format,
        lessonId: lessonId,
        audioUrl: audioUrl,
        entries: session.entries,
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
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ListenableBuilder(
        listenable: session,
        builder: (BuildContext context, Widget? _) {
          final entries = session.entries;
          final int totalDurationMs = entries.isEmpty
              ? 0
              : entries.fold(0, (sum, e) => sum + e.durationMs);

          return Row(
            children: <Widget>[
              // إحصائيات سريعة
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'export.segments_ready'.tr(
                        namedArgs: {'count': entries.length.toString()},
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (entries.isNotEmpty)
                      Text(
                        '${'entries.duration'.tr()}: ${TimingEntry.formatTime(totalDurationMs)}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // خيارات التصدير الأخرى للمطورين
              PopupMenuButton<ExportFormat>(
                tooltip: 'export_formats.title'.tr(),
                enabled: !exporting && session.entries.isNotEmpty,
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (format) => _exportOtherFormat(context, format),
                itemBuilder: (context) => [
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
                ],
              ),
              const SizedBox(width: 6),

              // زر التصدير الرئيسي (JSON)
              FilledButton.icon(
                onPressed:
                    (exporting || session.entries.isEmpty) ? null : onExport,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_rounded, size: 18),
                label: Text('common.export'.tr()),
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../controllers/timing_session.dart';
import '../models/timing_entry.dart';
import '../services/quran_font_service.dart';
import 'segment_edit_dialog.dart';

Future<void> _handlePlayEntry(
  TimingSession session,
  TimingEntry entry,
) async {
  await session.playEntryPreview(entry);
}

class EntriesList extends StatefulWidget {
  const EntriesList({super.key, required this.session});

  final TimingSession session;

  @override
  State<EntriesList> createState() => _EntriesListState();
}

class _EntriesListState extends State<EntriesList> {
  final ScrollController _scrollController = ScrollController();
  int _previousCount = 0;
  SegmentType? _filterType; // null = عرض الكل

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.session,
      builder: (BuildContext context, Widget? _) {
        final List<TimingEntry> allEntries = widget.session.entries;
        final List<TimingEntry> displayedEntries = _filterType == null
            ? allEntries
            : allEntries.where((e) => e.type == _filterType).toList();

        if (allEntries.length > _previousCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            }
          });
        }
        _previousCount = allEntries.length;

        return Column(
          children: <Widget>[
            _PendingBanner(session: widget.session),
            _UpcomingScriptCard(session: widget.session),
            if (allEntries.isNotEmpty) _buildFilterBar(allEntries),
            Expanded(
              child: displayedEntries.isEmpty
                  ? _EmptyPlaceholder(
                      hasFile: widget.session.sourceFilePath != null,
                      isFiltered: _filterType != null,
                    )
                  : StreamBuilder<Duration>(
                      stream: widget.session.player.positionStream,
                      builder: (context, posSnap) {
                        final currentPosMs =
                            posSnap.data?.inMilliseconds ?? 0;

                        return ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                          itemCount: displayedEntries.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (BuildContext context, int index) {
                            final TimingEntry entry = displayedEntries[index];
                            final bool isPlayingPreview =
                                widget.session.previewingEntryId == entry.id &&
                                    widget.session.player.playing;
                            final bool isCurrent = isPlayingPreview ||
                                (currentPosMs >= entry.startMs &&
                                    currentPosMs <= entry.endMs);

                            return _EntryTile(
                              entry: entry,
                              isCurrent: isCurrent,
                              isPlaying: isPlayingPreview ||
                                  (isCurrent && widget.session.player.playing),
                              onDelete: () =>
                                  widget.session.deleteEntry(entry.id),
                              onPlay: () => _handlePlayEntry(
                                widget.session,
                                entry,
                              ),
                              onEdit: () async {
                                final updated = await showDialog<TimingEntry>(
                                  context: context,
                                  builder: (_) =>
                                      SegmentEditDialog(entry: entry),
                                );
                                if (updated != null) {
                                  widget.session.updateEntry(updated);
                                }
                              },
                              onQuickEditTime: () async {
                                final updated = await showDialog<TimingEntry>(
                                  context: context,
                                  builder: (_) => QuickTimestampEditDialog(
                                    entry: entry,
                                    session: widget.session,
                                  ),
                                );
                                if (updated != null) {
                                  widget.session.updateEntry(updated);
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar(List<TimingEntry> entries) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isLight ? 0.35 : 0.25),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.05 : 0.15),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: Text('${'filter.all'.tr()} (${entries.length})'),
              selected: _filterType == null,
              onSelected: (_) => setState(() => _filterType = null),
            ),
            const SizedBox(width: 6),
            ...SegmentType.values.map((type) {
              final count = entries.where((e) => e.type == type).length;
              if (count == 0) return const SizedBox.shrink();
              final isSelected = _filterType == type;
              final brightness = Theme.of(context).brightness;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  avatar: Icon(type.icon, size: 14, color: type.colorFor(brightness)),
                  label: Text('${type.shortNameKey.tr()} ($count)'),
                  selected: isSelected,
                  selectedColor: type.bgBadgeFor(brightness),
                  onSelected: (_) => setState(() {
                    _filterType = isSelected ? null : type;
                  }),
                ),
              );
            }),
            const SizedBox(width: 6),
            ActionChip(
              avatar: Icon(
                widget.session.isPreviewLoop
                    ? Icons.repeat_on_rounded
                    : Icons.repeat_rounded,
                size: 15,
                color: widget.session.isPreviewLoop
                    ? scheme.primary
                    : Theme.of(context).hintColor,
              ),
              label: Text(
                'entries.loop_preview'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: widget.session.isPreviewLoop
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: widget.session.isPreviewLoop ? scheme.primary : null,
                ),
              ),
              backgroundColor: widget.session.isPreviewLoop
                  ? scheme.primaryContainer.withValues(alpha: 0.35)
                  : null,
              side: widget.session.isPreviewLoop
                  ? BorderSide(color: scheme.primary.withValues(alpha: 0.5))
                  : null,
              onPressed: () => widget.session.togglePreviewLoop(),
              tooltip: 'entries.loop_preview_tooltip'.tr(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.session});

  final TimingSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (BuildContext context, Widget? _) {
        if (!session.hasPendingStart) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        final type = session.activeType;

        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              bottom: BorderSide(
                color: scheme.error.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.error.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Card(
            margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            color: scheme.errorContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: scheme.error.withValues(alpha: 0.6)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: <Widget>[
                  Icon(Icons.radio_button_checked_rounded,
                      color: scheme.onErrorContainer, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'recording.pending_banner'.tr(namedArgs: {
                        'type': type.nameKey.tr(),
                        'count': session.nextVerse.toString(),
                        'start': TimingEntry.formatTime(session.pendingStartMs ?? 0),
                        'hint': 'recording.press_enter_at_end'.tr(),
                      }),
                      style: TextStyle(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'recording.cancel_tooltip'.tr(),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.error.withValues(alpha: 0.15),
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(28, 28),
                  ),
                  onPressed: () => session.cancelPendingStart(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: scheme.onErrorContainer,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder({
    required this.hasFile,
    this.isFiltered = false,
  });

  final bool hasFile;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHighest
                    .withValues(alpha: isLight ? 0.7 : 0.4),
                border: Border.all(
                  color: scheme.outlineVariant
                      .withValues(alpha: isLight ? 0.6 : 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.08),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                isFiltered
                    ? Icons.filter_alt_off_outlined
                    : Icons.playlist_add_check_circle_outlined,
                size: 32,
                color: isFiltered
                    ? scheme.outline
                    : scheme.primary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isFiltered
                  ? 'filter.no_results'.tr()
                  : 'entries.no_timestamps'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            if (hasFile)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer
                      .withValues(alpha: isLight ? 0.35 : 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Enter ↵',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'keyboard.enter_desc'.tr(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                'file.select_file_first'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                      fontSize: 11.5,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.isCurrent,
    required this.isPlaying,
    required this.onDelete,
    required this.onPlay,
    required this.onEdit,
    required this.onQuickEditTime,
  });

  final TimingEntry entry;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onDelete;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onQuickEditTime;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    final typeColor = entry.type.colorFor(brightness);
    final typeBg = entry.type.bgBadgeFor(brightness);

    return Stack(
      children: [
        Card(
          margin: EdgeInsets.zero,
          elevation: isCurrent ? 1 : 0,
          color: isCurrent
              ? (isLight
                  ? scheme.primaryContainer.withValues(alpha: 0.4)
                  : typeColor.withValues(alpha: 0.15))
              : scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isCurrent
                  ? (isLight ? scheme.primary : typeColor)
                  : scheme.outlineVariant.withValues(alpha: isLight ? 0.6 : 0.3),
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            dense: true,
            onTap: onPlay,
            contentPadding: EdgeInsets.only(
              left: isCurrent ? 14 : 10,
              right: 10,
              top: 2,
              bottom: 2,
            ),
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: typeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                entry.type.icon,
                size: 20,
                color: typeColor,
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${entry.type.shortNameKey.tr()} #${entry.verseNumber}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                      color: typeColor,
                    ),
                  ),
                ),
                if (entry.page != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: isLight ? 0.6 : 0.4),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: scheme.outlineVariant
                            .withValues(alpha: isLight ? 0.8 : 0.5),
                      ),
                    ),
                    child: Text(
                      '${'edit.page'.tr()} ${entry.page}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                if (entry.label != null && entry.label!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ] else ...[
                  const Spacer(),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 3),
                Directionality(
                  textDirection: ui.TextDirection.ltr,
                  child: Tooltip(
                    message: 'entries.quick_edit_time'.tr(),
                    child: InkWell(
                      onTap: onQuickEditTime,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                      margin: const EdgeInsets.only(top: 2, bottom: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? (isLight
                                ? scheme.primary.withValues(alpha: 0.12)
                                : typeColor.withValues(alpha: 0.2))
                            : scheme.surfaceContainerHighest
                                .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCurrent
                              ? (isLight
                                  ? scheme.primary.withValues(alpha: 0.3)
                                  : typeColor.withValues(alpha: 0.4))
                              : scheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: isCurrent
                                ? (isLight ? scheme.primary : typeColor)
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${TimingEntry.formatTime(entry.startMs)} → ${TimingEntry.formatTime(entry.endMs)}  (${(entry.durationMs / 1000).toStringAsFixed(1)}s)',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isCurrent
                                  ? (isLight ? scheme.primary : typeColor)
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_note_rounded,
                            size: 14,
                            color: isCurrent
                                ? (isLight ? scheme.primary : typeColor)
                                : scheme.outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
                if (entry.textArabic != null && entry.textArabic!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      entry.textArabic!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: ui.TextDirection.rtl,
                      style: TextStyle(
                        fontFamily:
                            QuranFontService.getFontFamilyForPage(entry.page),
                        fontSize: 16,
                        height: 1.65,
                        color: isCurrent
                            ? scheme.onSurface
                            : scheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'entries.quick_edit_time'.tr(),
                  onPressed: onQuickEditTime,
                  icon: const Icon(Icons.av_timer_rounded, size: 19),
                ),
                IconButton(
                  tooltip: 'entries.edit_tooltip'.tr(),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                IconButton(
                  tooltip: isPlaying
                      ? 'entries.verify_pause'.tr()
                      : 'entries.verify_play'.tr(),
                  onPressed: onPlay,
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_outline_rounded,
                    color: isPlaying ? scheme.primary : typeColor,
                    size: 22,
                  ),
                ),
                IconButton(
                  tooltip: 'entries.delete_entry'.tr(),
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline_rounded,
                      color: scheme.error, size: 19),
                ),
              ],
            ),
          ),
        ),
        // شريط مؤشر متحرك على اليسار للعنصر النشط حالياً
        Positioned(
          left: 1.5,
          top: 1.5,
          bottom: 1.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isCurrent ? 3 : 0,
            decoration: BoxDecoration(
              color: typeColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8.5),
                bottomLeft: Radius.circular(8.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UpcomingScriptCard extends StatelessWidget {
  const _UpcomingScriptCard({required this.session});

  final TimingSession session;

  @override
  Widget build(BuildContext context) {
    if (!session.hasPreloadedScript) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final item = session.currentScriptItem;
    if (item == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      decoration: BoxDecoration(
        color: isLight
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.primary.withValues(alpha: isLight ? 0.45 : 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.queue_play_next_rounded,
                          size: 13, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        'entries.upcoming_verse'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (item.surahName != null) ...[
                  Text(
                    item.surahName!,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  '#${item.verseNumber ?? session.nextVerse}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: scheme.primary,
                  ),
                ),
                if (item.page != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      '${'edit.page'.tr()} ${item.page}',
                      style: TextStyle(
                          fontSize: 10, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${session.currentScriptVerseIndex} / ${session.totalScriptCount} (${'entries.remaining'.tr()}: ${session.remainingScriptCount})',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 110),
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    item.text,
                    textDirection: ui.TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily:
                          QuranFontService.getFontFamilyForPage(item.page),
                      fontSize: 17,
                      height: 1.6,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: session.canPrevScriptLine
                      ? () => session.prevScriptLine()
                      : null,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 14),
                  label: Text('entries.prev_line'.tr(),
                      style: const TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: session.canSkipScriptLine
                      ? () => session.skipScriptLine()
                      : null,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.skip_next_rounded, size: 14),
                  label: Text('entries.skip_line'.tr(),
                      style: const TextStyle(fontSize: 11)),
                ),
                const Spacer(),
                Text(
                  'keyboard.enter_desc'.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class QuickTimestampEditDialog extends StatefulWidget {
  const QuickTimestampEditDialog({
    super.key,
    required this.entry,
    required this.session,
  });

  final TimingEntry entry;
  final TimingSession session;

  @override
  State<QuickTimestampEditDialog> createState() =>
      _QuickTimestampEditDialogState();
}

class _QuickTimestampEditDialogState extends State<QuickTimestampEditDialog> {
  late int _startMs;
  late int _endMs;

  @override
  void initState() {
    super.initState();
    _startMs = widget.entry.startMs;
    _endMs = widget.entry.endMs;
  }

  void _adjustStart(int delta) {
    setState(() {
      _startMs = math.max(0, math.min(_startMs + delta, _endMs - 50));
    });
  }

  void _adjustEnd(int delta) {
    final maxLimit =
        widget.session.player.duration?.inMilliseconds ?? 999999999;
    setState(() {
      _endMs = math.min(maxLimit, math.max(_endMs + delta, _startMs + 50));
    });
  }

  void _setStartToCurrentPlayhead() {
    final currentPos = widget.session.player.position.inMilliseconds;
    if (currentPos < _endMs) {
      setState(() => _startMs = currentPos);
    }
  }

  void _setEndToCurrentPlayhead() {
    final currentPos = widget.session.player.position.inMilliseconds;
    if (currentPos > _startMs) {
      setState(() => _endMs = currentPos);
    }
  }

  Future<void> _preview() async {
    final tempEntry = widget.entry.copyWith(startMs: _startMs, endMs: _endMs);
    await widget.session.playEntryPreview(tempEntry);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final durationSec = ((_endMs - _startMs) / 1000).toStringAsFixed(2);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.av_timer_rounded, color: scheme.primary, size: 22),
          const SizedBox(width: 8),
          Text('entries.quick_edit_time'.tr()),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${widget.entry.type.shortNameKey.tr()} #${widget.entry.verseNumber}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder<Duration>(
              stream: widget.session.player.positionStream,
              builder: (context, snap) {
                final posMs = snap.data?.inMilliseconds ??
                    widget.session.player.position.inMilliseconds;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow_outlined,
                          size: 16, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'entries.use_current_pos'.tr(),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        TimingEntry.formatTime(posMs),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            _buildTimeSection(
              title: 'entries.start_time'.tr(),
              timeMs: _startMs,
              onAdjust: _adjustStart,
              onSetCurrent: _setStartToCurrentPlayhead,
              color: scheme.primary,
              scheme: scheme,
            ),
            const SizedBox(height: 12),
            _buildTimeSection(
              title: 'entries.end_time'.tr(),
              timeMs: _endMs,
              onAdjust: _adjustEnd,
              onSetCurrent: _setEndToCurrentPlayhead,
              color: Colors.deepOrange,
              scheme: scheme,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Text(
                    '${'entries.duration'.tr()}: ',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  Text(
                    '$durationSec s',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: _preview,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 16),
                    label: Text('entries.preview_clip'.tr()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () {
            final updated =
                widget.entry.copyWith(startMs: _startMs, endMs: _endMs);
            Navigator.of(context).pop(updated);
          },
          child: Text('entries.save_time'.tr()),
        ),
      ],
    );
  }

  Widget _buildTimeSection({
    required String title,
    required int timeMs,
    required void Function(int) onAdjust,
    required VoidCallback onSetCurrent,
    required Color color,
    required ColorScheme scheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  TimingEntry.formatTime(timeMs),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'entries.use_current_pos'.tr(),
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                onPressed: onSetCurrent,
                icon: const Icon(Icons.my_location_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _nudgeChip('-500ms', () => onAdjust(-500), scheme),
              _nudgeChip('-100ms', () => onAdjust(-100), scheme),
              _nudgeChip('-50ms', () => onAdjust(-50), scheme),
              _nudgeChip('+50ms', () => onAdjust(50), scheme),
              _nudgeChip('+100ms', () => onAdjust(100), scheme),
              _nudgeChip('+500ms', () => onAdjust(500), scheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nudgeChip(String label, VoidCallback onTap, ColorScheme scheme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
      ),
    );
  }
}

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
  bool isCurrent,
) async {
  if (isCurrent && session.player.playing) {
    await session.player.pause();
    return;
  }
  final targetMs = entry.startMs;
  final currentMs = session.player.position.inMilliseconds;
  await session.seekRelative(targetMs - currentMs);
  if (!session.player.playing) {
    await session.player.play();
  }
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
                            final bool isCurrent =
                                currentPosMs >= entry.startMs &&
                                    currentPosMs <= entry.endMs;

                            return _EntryTile(
                              entry: entry,
                              isCurrent: isCurrent,
                              isPlaying: isCurrent && widget.session.player.playing,
                              onDelete: () =>
                                  widget.session.deleteEntry(entry.id),
                              onPlay: () => _handlePlayEntry(
                                widget.session,
                                entry,
                                isCurrent,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

        return Card(
          margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          color: scheme.errorContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: scheme.error.withValues(alpha: 0.6)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(Icons.radio_button_checked_rounded,
                    color: scheme.onErrorContainer, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${type.nameKey.tr()} #${session.nextVerse} قيد التسجيل — '
                    'البداية ${TimingEntry.formatTime(session.pendingStartMs ?? 0)}. '
                    '${'recording.press_enter_at_end'.tr()}.',
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered
                    ? Icons.filter_alt_off_outlined
                    : Icons.playlist_add_check_rounded,
                size: 40,
                color: scheme.outline,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isFiltered
                  ? 'لا توجد عناصر مطابقة للتصفية'
                  : 'entries.no_timestamps'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFile
                  ? '${'keyboard.enter'.tr()} = ${'keyboard.enter_desc'.tr()}'
                  : 'file.select_file_first'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
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
  });

  final TimingEntry entry;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onDelete;
  final VoidCallback onPlay;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    final typeColor = entry.type.colorFor(brightness);
    final typeBg = entry.type.bgBadgeFor(brightness);

    return Card(
      margin: EdgeInsets.zero,
      elevation: isCurrent ? 1 : 0,
      color: isCurrent
          ? (isLight ? scheme.primaryContainer.withValues(alpha: 0.4) : typeColor.withValues(alpha: 0.15))
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
      child: ListTile(
        dense: true,
        onTap: onPlay,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: isLight ? 0.6 : 0.4),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: isLight ? 0.8 : 0.5),
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
              child: Text(
                '${TimingEntry.formatTime(entry.startMs)} → ${TimingEntry.formatTime(entry.endMs)}  (${(entry.durationMs / 1000).toStringAsFixed(1)}s)',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent
                      ? (isLight ? scheme.primary : typeColor)
                      : scheme.onSurfaceVariant,
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
                    fontFamily: QuranFontService.getFontFamilyForPage(entry.page),
                    fontSize: 16,
                    height: 1.65,
                    color: isCurrent ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'تعديل',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
            IconButton(
              tooltip: 'entries.verify_play'.tr(),
              onPressed: onPlay,
              icon: Icon(
                isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_outline_rounded,
                color: typeColor,
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
    );
  }
}

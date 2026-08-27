import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/timing_entry.dart';

class WaveformWidget extends StatefulWidget {
  const WaveformWidget({
    super.key,
    required this.peaks,
    required this.position,
    required this.duration,
    required this.entries,
    required this.onSeek,
    this.pendingStartMs,
    this.activeType = SegmentType.quran,
    this.height = 140,
  });

  final List<double> peaks;
  final Duration position;
  final Duration duration;
  final List<TimingEntry> entries;
  final void Function(Duration) onSeek;
  final int? pendingStartMs;
  final SegmentType activeType;
  final double height;

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget> {
  final ScrollController _scrollController = ScrollController();
  double _zoomLevel = 1.0; // 1.0 = fit to container width, 2.0 = 2x, etc.
  double? _hoverMs;
  bool _isDragging = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSeekAtLocalX(double localX, double totalWidth) {
    if (widget.duration <= Duration.zero || totalWidth <= 0) return;
    final clampedX = localX.clamp(0.0, totalWidth);
    final progress = clampedX / totalWidth;
    final targetMs = (widget.duration.inMilliseconds * progress).round();
    widget.onSeek(Duration(milliseconds: targetMs));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (widget.peaks.isEmpty) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.graphic_eq_rounded,
              size: 36,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 6),
            Text(
              'player.no_waveform_data'.tr(),
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;
        final totalWidth = containerWidth * _zoomLevel;

        return Stack(
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onHover: (event) {
                if (widget.duration > Duration.zero) {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    final localPos = renderBox.globalToLocal(event.position);
                    final scrollOffset = _scrollController.hasClients
                        ? _scrollController.offset
                        : 0.0;
                    final realX = localPos.dx + scrollOffset;
                    final progress = (realX / totalWidth).clamp(0.0, 1.0);
                    setState(() {
                      _hoverMs = (widget.duration.inMilliseconds * progress).toDouble();
                    });
                  }
                }
              },
              onExit: (_) {
                setState(() => _hoverMs = null);
              },
              child: GestureDetector(
                onTapDown: (details) {
                  final scrollOffset = _scrollController.hasClients
                      ? _scrollController.offset
                      : 0.0;
                  final localX = details.localPosition.dx + scrollOffset;
                  _handleSeekAtLocalX(localX, totalWidth);
                },
                onHorizontalDragStart: (details) {
                  _isDragging = true;
                  final scrollOffset = _scrollController.hasClients
                      ? _scrollController.offset
                      : 0.0;
                  final localX = details.localPosition.dx + scrollOffset;
                  _handleSeekAtLocalX(localX, totalWidth);
                },
                onHorizontalDragUpdate: (details) {
                  final scrollOffset = _scrollController.hasClients
                      ? _scrollController.offset
                      : 0.0;
                  final localX = details.localPosition.dx + scrollOffset;
                  _handleSeekAtLocalX(localX, totalWidth);
                },
                onHorizontalDragEnd: (_) {
                  _isDragging = false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: _isDragging
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  child: CustomPaint(
                    size: Size(totalWidth, widget.height),
                    painter: _WaveformPainter(
                      peaks: widget.peaks,
                      height: widget.height,
                      position: widget.position,
                      duration: widget.duration,
                      entries: widget.entries,
                      pendingStartMs: widget.pendingStartMs,
                      activeType: widget.activeType,
                      themeScheme: scheme,
                    ),
                  ),
                ),
              ),
            ),

            // شارة التكبير / التصغير في الزاوية
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hoverMs != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          TimingEntry.formatTime(_hoverMs!.toInt()),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      Container(
                        height: 12,
                        width: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ],
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 14,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                      tooltip: 'player.zoom_out'.tr(),
                      icon: const Icon(Icons.remove_rounded),
                      onPressed: _zoomLevel <= 1.0
                          ? null
                          : () => setState(() => _zoomLevel = math.max(1.0, _zoomLevel - 0.5)),
                    ),
                    Text(
                      '${_zoomLevel.toStringAsFixed(1)}x',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 14,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                      tooltip: 'player.zoom_in'.tr(),
                      icon: const Icon(Icons.add_rounded),
                      onPressed: _zoomLevel >= 4.0
                          ? null
                          : () => setState(() => _zoomLevel = math.min(4.0, _zoomLevel + 0.5)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> peaks;
  final double height;
  final Duration position;
  final Duration duration;
  final List<TimingEntry> entries;
  final int? pendingStartMs;
  final SegmentType activeType;
  final ColorScheme themeScheme;

  _WaveformPainter({
    required this.peaks,
    required this.height,
    required this.position,
    required this.duration,
    required this.entries,
    required this.pendingStartMs,
    required this.activeType,
    required this.themeScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;

    final double width = size.width;
    final double centerY = height / 2;
    final double maxAmp = height * 0.42;

    final double playedRatio = duration > Duration.zero
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final double playedX = playedRatio * width;

    final isLight = themeScheme.brightness == Brightness.light;

    // رسم أعمدة الموجة
    final int numBars = peaks.length;
    final double barWidth = width / numBars;
    final double barSpacing = math.max(1.0, barWidth * 0.35);
    final double actualBarWidth = math.max(1.2, barWidth - barSpacing);

    final bgPaint = Paint()
      ..color = themeScheme.primary.withValues(alpha: isLight ? 0.20 : 0.25)
      ..strokeWidth = actualBarWidth
      ..strokeCap = StrokeCap.round;

    final playedPaint = Paint()
      ..color = themeScheme.primary
      ..strokeWidth = actualBarWidth
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < numBars; i++) {
      final x = i * barWidth + (barWidth / 2);
      final amp = peaks[i] * maxAmp;

      canvas.drawLine(
        Offset(x, centerY - amp),
        Offset(x, centerY + amp),
        x <= playedX ? playedPaint : bgPaint,
      );
    }

    // خط المحور المركزي
    final centerLinePaint = Paint()
      ..color = themeScheme.outlineVariant.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, centerY), Offset(width, centerY), centerLinePaint);

    // رسم المقاطع المسجلة
    if (duration > Duration.zero) {
      final pxPerMs = width / duration.inMilliseconds;

      for (final entry in entries) {
        final startX = entry.startMs * pxPerMs;
        final endX = entry.endMs * pxPerMs;
        final segWidth = endX - startX;

        if (segWidth < 1) continue;

        final segmentColor = entry.type.colorFor(themeScheme.brightness);

        // خلفية المقطع
        final rect = Rect.fromLTWH(startX, 0, segWidth, height);
        canvas.drawRect(
          rect,
          Paint()..color = segmentColor.withValues(alpha: isLight ? 0.12 : 0.20),
        );

        // خط علوي مميز
        canvas.drawLine(
          Offset(startX, 0),
          Offset(endX, 0),
          Paint()
            ..color = segmentColor
            ..strokeWidth = 3,
        );

        // حدود البداية والنهاية
        final borderPaint = Paint()
          ..color = segmentColor.withValues(alpha: isLight ? 0.8 : 0.7)
          ..strokeWidth = 1.2;
        canvas.drawLine(Offset(startX, 0), Offset(startX, height), borderPaint);
        canvas.drawLine(Offset(endX, 0), Offset(endX, height), borderPaint);

        // رقم المقطع
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${entry.verseNumber}',
            style: TextStyle(
              color: segmentColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(startX + 3, 4));
      }

      // رسم المقطع الجاري تسجيله حالياً (Pending Start)
      if (pendingStartMs != null) {
        final startX = pendingStartMs! * pxPerMs;
        final currentX = position.inMilliseconds * pxPerMs;
        final liveWidth = math.max(2.0, currentX - startX);
        final liveColor = activeType.colorFor(themeScheme.brightness);

        final rect = Rect.fromLTWH(startX, 0, liveWidth, height);
        canvas.drawRect(
          rect,
          Paint()..color = liveColor.withValues(alpha: isLight ? 0.25 : 0.35),
        );

        // خط علوي نابض
        canvas.drawLine(
          Offset(startX, 0),
          Offset(currentX, 0),
          Paint()
            ..color = liveColor
            ..strokeWidth = 3.5,
        );

        // خط بداية المقطع المعلق
        canvas.drawLine(
          Offset(startX, 0),
          Offset(startX, height),
          Paint()
            ..color = liveColor
            ..strokeWidth = 2,
        );
      }
    }

    // مؤشر التشغيل المتحرك (Playhead Needle)
    if (duration > Duration.zero) {
      final playheadPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0;

      // الخط العمودي الكامل
      canvas.drawLine(
        Offset(playedX, 0),
        Offset(playedX, height),
        playheadPaint,
      );

      // رأس المؤشر في الأعلى
      final pathTop = Path()
        ..moveTo(playedX - 5, 0)
        ..lineTo(playedX + 5, 0)
        ..lineTo(playedX, 7)
        ..close();
      canvas.drawPath(pathTop, Paint()..color = Colors.white);

      // رأس المؤشر في الأسفل
      final pathBottom = Path()
        ..moveTo(playedX - 5, height)
        ..lineTo(playedX + 5, height)
        ..lineTo(playedX, height - 7)
        ..close();
      canvas.drawPath(pathBottom, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.duration != duration ||
        oldDelegate.peaks != peaks ||
        oldDelegate.entries != entries ||
        oldDelegate.pendingStartMs != pendingStartMs ||
        oldDelegate.activeType != activeType ||
        oldDelegate.themeScheme != themeScheme;
  }
}

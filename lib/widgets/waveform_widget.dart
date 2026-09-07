import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/timing_entry.dart';

enum WaveformEdgeType { start, end }

class _HoveredEdge {
  final TimingEntry entry;
  final WaveformEdgeType edgeType;
  final double x;

  const _HoveredEdge({
    required this.entry,
    required this.edgeType,
    required this.x,
  });
}

class _ActiveDragEdge {
  final TimingEntry entry;
  final WaveformEdgeType edgeType;
  final int initialMs;
  int currentMs;

  _ActiveDragEdge({
    required this.entry,
    required this.edgeType,
    required this.initialMs,
    required this.currentMs,
  });
}

class WaveformWidget extends StatefulWidget {
  const WaveformWidget({
    super.key,
    required this.peaks,
    required this.position,
    required this.duration,
    required this.entries,
    required this.onSeek,
    this.onEntryChanged,
    this.pendingStartMs,
    this.activeType = SegmentType.quran,
    this.height = 140,
  });

  final List<double> peaks;
  final Duration position;
  final Duration duration;
  final List<TimingEntry> entries;
  final void Function(Duration) onSeek;
  final void Function(TimingEntry updatedEntry)? onEntryChanged;
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
  bool _isDraggingSeek = false;
  bool _isDraggingEdge = false;
  _HoveredEdge? _hoveredEdge;
  _ActiveDragEdge? _activeDrag;

  static const double _edgeHitThreshold = 8.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double? _dragDownLocalX;

  _HoveredEdge? _findEdgeAtLocalX(double localX, double totalWidth) {
    if (widget.duration <= Duration.zero || totalWidth <= 0) return null;
    if (widget.entries.isEmpty || widget.onEntryChanged == null) return null;

    final pxPerMs = totalWidth / widget.duration.inMilliseconds;
    for (final entry in widget.entries) {
      final startX = entry.startMs * pxPerMs;
      final endX = entry.endMs * pxPerMs;
      if ((localX - startX).abs() <= _edgeHitThreshold) {
        return _HoveredEdge(entry: entry, edgeType: WaveformEdgeType.start, x: startX);
      }
      if ((localX - endX).abs() <= _edgeHitThreshold) {
        return _HoveredEdge(entry: entry, edgeType: WaveformEdgeType.end, x: endX);
      }
    }
    return null;
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
            SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: (_zoomLevel <= 1.0 || _isDraggingSeek || _isDraggingEdge)
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              child: MouseRegion(
                cursor: _isDraggingEdge || _hoveredEdge != null
                    ? SystemMouseCursors.resizeColumn
                    : SystemMouseCursors.click,
                onHover: (event) {
                  if (widget.duration > Duration.zero) {
                    final realX = event.localPosition.dx;
                    final progress = (realX / totalWidth).clamp(0.0, 1.0);
                    final currentHoverMs = (widget.duration.inMilliseconds * progress).toDouble();

                    final foundEdge = !_isDraggingEdge
                        ? _findEdgeAtLocalX(realX, totalWidth)
                        : null;

                    setState(() {
                      _hoverMs = currentHoverMs;
                      _hoveredEdge = foundEdge;
                    });
                  }
                },
                onExit: (_) {
                  if (!_isDraggingEdge) {
                    setState(() {
                      _hoverMs = null;
                      _hoveredEdge = null;
                    });
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final localX = details.localPosition.dx;
                    if (_findEdgeAtLocalX(localX, totalWidth) != null) return;
                    _handleSeekAtLocalX(localX, totalWidth);
                  },
                  onHorizontalDragDown: (details) {
                    _dragDownLocalX = details.localPosition.dx;
                  },
                  onHorizontalDragStart: (details) {
                    final localX = details.localPosition.dx;
                    final checkX = _dragDownLocalX ?? localX;
                    _dragDownLocalX = null;
                    final edgeToDrag = _hoveredEdge ?? _findEdgeAtLocalX(checkX, totalWidth);

                    if (edgeToDrag != null && widget.onEntryChanged != null) {
                      _isDraggingEdge = true;
                      _isDraggingSeek = false;
                      final entry = edgeToDrag.entry;
                      final edgeType = edgeToDrag.edgeType;
                      final initialMs = edgeType == WaveformEdgeType.start
                          ? entry.startMs
                          : entry.endMs;

                      setState(() {
                        _activeDrag = _ActiveDragEdge(
                          entry: entry,
                          edgeType: edgeType,
                          initialMs: initialMs,
                          currentMs: initialMs,
                        );
                      });
                    } else {
                      _isDraggingSeek = true;
                      _isDraggingEdge = false;
                      _handleSeekAtLocalX(localX, totalWidth);
                    }
                  },
                  onHorizontalDragUpdate: (details) {
                    final localX = details.localPosition.dx;

                    if (_isDraggingEdge && _activeDrag != null) {
                      final progress = (localX / totalWidth).clamp(0.0, 1.0);
                      final rawMs = (widget.duration.inMilliseconds * progress).round();
                      final entry = _activeDrag!.entry;

                      int clampedMs;
                      if (_activeDrag!.edgeType == WaveformEdgeType.start) {
                        const int minStart = 0;
                        final int maxStart = math.max(0, entry.endMs - 100);
                        clampedMs = rawMs.clamp(minStart, maxStart);
                      } else {
                        final int minEnd = entry.startMs + 100;
                        final int maxEnd = widget.duration.inMilliseconds;
                        clampedMs = rawMs.clamp(minEnd, maxEnd);
                      }

                      setState(() {
                        _activeDrag!.currentMs = clampedMs;
                        _hoverMs = clampedMs.toDouble();
                      });
                    } else if (_isDraggingSeek) {
                      _handleSeekAtLocalX(localX, totalWidth);
                    }
                  },
                  onHorizontalDragEnd: (_) {
                    if (_isDraggingEdge && _activeDrag != null) {
                      final entry = _activeDrag!.entry;
                      final edgeType = _activeDrag!.edgeType;
                      final newMs = _activeDrag!.currentMs;

                      TimingEntry? updated;
                      if (edgeType == WaveformEdgeType.start && newMs != entry.startMs) {
                        updated = entry.copyWith(startMs: newMs);
                      } else if (edgeType == WaveformEdgeType.end && newMs != entry.endMs) {
                        updated = entry.copyWith(endMs: newMs);
                      }

                      if (updated != null) {
                        widget.onEntryChanged?.call(updated);
                      }

                      setState(() {
                        _activeDrag = null;
                        _isDraggingEdge = false;
                        _hoveredEdge = null;
                      });
                    } else {
                      _isDraggingSeek = false;
                    }
                  },
                  onHorizontalDragCancel: () {
                    setState(() {
                      _activeDrag = null;
                      _isDraggingEdge = false;
                      _isDraggingSeek = false;
                      _hoveredEdge = null;
                    });
                  },
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
                      hoveredEdge: _hoveredEdge,
                      activeDrag: _activeDrag,
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
  final _HoveredEdge? hoveredEdge;
  final _ActiveDragEdge? activeDrag;

  _WaveformPainter({
    required this.peaks,
    required this.height,
    required this.position,
    required this.duration,
    required this.entries,
    required this.pendingStartMs,
    required this.activeType,
    required this.themeScheme,
    this.hoveredEdge,
    this.activeDrag,
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
    final pxPerMs = duration > Duration.zero ? width / duration.inMilliseconds : 0.0;

    // 1. رسم خلفيات المقاطع المسجلة أولاً لتكون خلف أعمدة الموجة ولا تطمس تفاصيلها
    if (pxPerMs > 0) {
      for (final entry in entries) {
        final int effectiveStartMs = (activeDrag != null &&
                activeDrag!.entry.id == entry.id &&
                activeDrag!.edgeType == WaveformEdgeType.start)
            ? activeDrag!.currentMs
            : entry.startMs;

        final int effectiveEndMs = (activeDrag != null &&
                activeDrag!.entry.id == entry.id &&
                activeDrag!.edgeType == WaveformEdgeType.end)
            ? activeDrag!.currentMs
            : entry.endMs;

        final startX = effectiveStartMs * pxPerMs;
        final endX = effectiveEndMs * pxPerMs;
        final segWidth = endX - startX;

        if (segWidth < 1) continue;

        final segmentColor = entry.type.colorFor(themeScheme.brightness);
        final rect = Rect.fromLTWH(startX, 0, segWidth, height);
        canvas.drawRect(
          rect,
          Paint()..color = segmentColor.withValues(alpha: isLight ? 0.12 : 0.18),
        );
      }
    }

    // 2. رسم أعمدة الموجة الصوتية فوق الخلفيات لتبقى واضحة بدقة
    final int numBars = peaks.length;
    final double barWidth = width / numBars;
    final double barSpacing = math.max(1.0, barWidth * 0.35);
    final double actualBarWidth = math.max(1.2, barWidth - barSpacing);

    final bgPaint = Paint()
      ..color = themeScheme.primary.withValues(alpha: isLight ? 0.30 : 0.40)
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

    // 3. رسم حواف المقاطع، المقابض، والأرقام المتناوبة لمنع التداخل
    if (pxPerMs > 0) {
      for (final entry in entries) {
        final int effectiveStartMs = (activeDrag != null &&
                activeDrag!.entry.id == entry.id &&
                activeDrag!.edgeType == WaveformEdgeType.start)
            ? activeDrag!.currentMs
            : entry.startMs;

        final int effectiveEndMs = (activeDrag != null &&
                activeDrag!.entry.id == entry.id &&
                activeDrag!.edgeType == WaveformEdgeType.end)
            ? activeDrag!.currentMs
            : entry.endMs;

        final startX = effectiveStartMs * pxPerMs;
        final endX = effectiveEndMs * pxPerMs;
        final segWidth = endX - startX;

        if (segWidth < 1) continue;

        final segmentColor = entry.type.colorFor(themeScheme.brightness);

        // خط علوي مميز للمقطع
        canvas.drawLine(
          Offset(startX, 0),
          Offset(endX, 0),
          Paint()
            ..color = segmentColor
            ..strokeWidth = 3,
        );

        // رسم مقابض وحواف البداية والنهاية
        _drawEdgeHandle(
          canvas: canvas,
          x: startX,
          height: height,
          segmentColor: segmentColor,
          isStart: true,
          isHovered: hoveredEdge != null &&
              hoveredEdge!.entry.id == entry.id &&
              hoveredEdge!.edgeType == WaveformEdgeType.start,
          isDragged: activeDrag != null &&
              activeDrag!.entry.id == entry.id &&
              activeDrag!.edgeType == WaveformEdgeType.start,
        );

        _drawEdgeHandle(
          canvas: canvas,
          x: endX,
          height: height,
          segmentColor: segmentColor,
          isStart: false,
          isHovered: hoveredEdge != null &&
              hoveredEdge!.entry.id == entry.id &&
              hoveredEdge!.edgeType == WaveformEdgeType.end,
          isDragged: activeDrag != null &&
              activeDrag!.entry.id == entry.id &&
              activeDrag!.edgeType == WaveformEdgeType.end,
        );

        // رقم المقطع متناوب رأسياً (Staggered) لمنع تداخل الأرقام عند المقاطع القصيرة
        final isHoveredOrDragged = (hoveredEdge != null && hoveredEdge!.entry.id == entry.id) ||
            (activeDrag != null && activeDrag!.entry.id == entry.id);

        if (segWidth >= 14 || isHoveredOrDragged) {
          final isEven = entry.verseNumber % 2 == 0;
          final double labelY = isEven ? 4.0 : 20.0;

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

          // خلفية حبة مريحة للعين لمنع تداخل النص مع خطوط الموجة
          final pillRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(startX + 2, labelY, textPainter.width + 5, textPainter.height + 2),
            const Radius.circular(3),
          );
          canvas.drawRRect(
            pillRect,
            Paint()..color = (isLight ? Colors.white : const Color(0xFF070B13)).withValues(alpha: 0.88),
          );
          textPainter.paint(canvas, Offset(startX + 4, labelY + 1));
        }
      }

      // رسم المقطع الجاري تسجيله حالياً (Glowing Active Segment Backdrop)
      if (pendingStartMs != null) {
        final startX = pendingStartMs! * pxPerMs;
        final currentX = position.inMilliseconds * pxPerMs;
        final liveWidth = math.max(2.0, currentX - startX);
        final liveColor = activeType.colorFor(themeScheme.brightness);

        final rect = Rect.fromLTWH(startX, 0, liveWidth, height);

        // تدرج ضوئي حي متوهج (Glowing Teal Gradient)
        final glowShader = ui.Gradient.linear(
          Offset(startX, 0),
          Offset(currentX, 0),
          [
            liveColor.withValues(alpha: isLight ? 0.16 : 0.22),
            liveColor.withValues(alpha: isLight ? 0.38 : 0.48),
          ],
        );
        canvas.drawRect(rect, Paint()..shader = glowShader);

        // خط علوي بوهج مضيء ساطع (Glowing Neon Top Border)
        canvas.drawLine(
          Offset(startX, 1),
          Offset(currentX, 1),
          Paint()
            ..color = liveColor.withValues(alpha: 0.5)
            ..strokeWidth = 6
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        canvas.drawLine(
          Offset(startX, 0),
          Offset(currentX, 0),
          Paint()
            ..color = liveColor
            ..strokeWidth = 3.5,
        );

        // خط بداية المقطع المعلق مع شارة علوية
        canvas.drawLine(
          Offset(startX, 0),
          Offset(startX, height),
          Paint()
            ..color = liveColor
            ..strokeWidth = 2.5,
        );
        canvas.drawCircle(Offset(startX, 4), 4, Paint()..color = liveColor);

        // خط المؤشر الجاري النشط في نهاية المقطع المفتوح
        canvas.drawLine(
          Offset(currentX, 0),
          Offset(currentX, height),
          Paint()
            ..color = liveColor.withValues(alpha: 0.9)
            ..strokeWidth = 2.0,
        );
      }

      // رسم شارة السحب التفاعلي الحي (Floating Badge)
      if (activeDrag != null) {
        final dragX = activeDrag!.currentMs * pxPerMs;
        final deltaMs = activeDrag!.currentMs - activeDrag!.initialMs;
        final deltaSign = deltaMs >= 0 ? '+$deltaMs ms' : '$deltaMs ms';
        final timeFormatted = TimingEntry.formatTime(activeDrag!.currentMs);
        final label = activeDrag!.edgeType == WaveformEdgeType.start
            ? '▶ $timeFormatted  ($deltaSign)'
            : '■ $timeFormatted  ($deltaSign)';

        final textSpan = TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        );
        final tp = TextPainter(
          text: textSpan,
          textDirection: ui.TextDirection.ltr,
        );
        tp.layout();

        final badgeW = tp.width + 16;
        final badgeH = tp.height + 8;
        final badgeLeft = (dragX - badgeW / 2).clamp(4.0, math.max(4.0, width - badgeW - 4.0)).toDouble();
        final badgeTop = math.max(4.0, (height / 2) - (badgeH / 2));

        final badgeRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(badgeLeft, badgeTop, badgeW, badgeH),
          const Radius.circular(6),
        );

        // خلفية داكنة مع إطار مميز
        canvas.drawRRect(
          badgeRect,
          Paint()..color = const Color(0xFA0F172A),
        );
        canvas.drawRRect(
          badgeRect,
          Paint()
            ..color = themeScheme.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );

        tp.paint(canvas, Offset(badgeLeft + 8, badgeTop + 4));
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

  void _drawEdgeHandle({
    required Canvas canvas,
    required double x,
    required double height,
    required Color segmentColor,
    required bool isStart,
    required bool isHovered,
    required bool isDragged,
  }) {
    final double lineWidth = isDragged ? 2.5 : (isHovered ? 2.0 : 1.2);
    final Color lineColor = isDragged
        ? themeScheme.primary
        : (isHovered ? Colors.white : segmentColor.withValues(alpha: 0.8));

    // رسم الخط العمودي
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, height),
      Paint()
        ..color = lineColor
        ..strokeWidth = lineWidth,
    );

    // مقابض تفاعلية علوية وسفلية (DAW Grip Caps)
    final double capW = isHovered || isDragged ? 8.0 : 5.0;
    final double capH = isHovered || isDragged ? 14.0 : 10.0;
    final capColor = isDragged
        ? themeScheme.primary
        : (isHovered ? Colors.white : segmentColor);

    // مقبض علوي
    final topRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, capH / 2), width: capW, height: capH),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(topRRect, Paint()..color = capColor);

    // مقبض سفلي
    final bottomRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, height - capH / 2), width: capW, height: capH),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(bottomRRect, Paint()..color = capColor);

    // عند التحويم أو السحب: رسم مقبض أوسط إضافي مع شكل هندسي أنيق
    if (isHovered || isDragged) {
      final midRRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, height / 2), width: capW, height: capH * 1.2),
        const Radius.circular(3),
      );
      canvas.drawRRect(midRRect, Paint()..color = capColor);
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
        oldDelegate.themeScheme != themeScheme ||
        oldDelegate.hoveredEdge != hoveredEdge ||
        oldDelegate.activeDrag != activeDrag;
  }
}

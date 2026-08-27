import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../controllers/timing_session.dart';
import '../models/timing_entry.dart';
import '../services/waveform_service.dart';
import '../widgets/waveform_widget.dart';

class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key, required this.session});

  final TimingSession session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListenableBuilder(
          listenable: session,
          builder: (BuildContext context, Widget? _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // عداد الوقت الرقمي الاحترافي (Studio Timecode)
                _TimecodeHeader(session: session),
                const SizedBox(height: 12),

                // قسم الموجة الصوتية التفاعلية
                _StudioWaveform(session: session),
                const SizedBox(height: 8),

                // شريط التمرير الدقيق
                _PositionSlider(player: session.player),
                const SizedBox(height: 8),

                // أزرار التحكم والسرعة والتعويض
                _StudioControlsBar(session: session),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TimecodeHeader extends StatelessWidget {
  const _TimecodeHeader({required this.session});

  final TimingSession session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<Duration>(
      stream: session.player.positionStream,
      builder: (BuildContext context, AsyncSnapshot<Duration> posSnap) {
        return StreamBuilder<Duration?>(
          stream: session.player.durationStream,
          builder: (BuildContext context, AsyncSnapshot<Duration?> durSnap) {
            final int posMs = posSnap.data?.inMilliseconds ?? 0;
            final int durMs = durSnap.data?.inMilliseconds ?? 0;

            return Row(
              children: [
                // العداد الرقمي
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                  ),
                  child: Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, size: 16, color: scheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          TimingEntry.formatTime(posMs),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          ' / ${TimingEntry.formatTime(durMs)}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                // شارة حالة التسجيل الحالية إن وجدت
                if (session.hasPendingStart)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: scheme.error.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: scheme.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'recording.pending_verse'.tr(namedArgs: {'count': session.nextVerse.toString()}),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StudioWaveform extends StatefulWidget {
  const _StudioWaveform({required this.session});

  final TimingSession session;

  @override
  State<_StudioWaveform> createState() => _StudioWaveformState();
}

class _StudioWaveformState extends State<_StudioWaveform> {
  // متتبع محلي للمسار المُولَّد - يحل مشكلة المقارنة بنفس النسخة
  String? _lastGeneratedPath;

  @override
  void initState() {
    super.initState();
    // الاستماع لـ WaveformService لإعادة البناء عند جاهزية الـ peaks
    WaveformService.instance.addListener(_onWaveformChanged);
    _checkAndGenerate();
  }

  @override
  void dispose() {
    WaveformService.instance.removeListener(_onWaveformChanged);
    super.dispose();
  }

  void _onWaveformChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _StudioWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAndGenerate();
  }

  void _checkAndGenerate() {
    final path = widget.session.sourceFilePath;
    if (path == null) return;
    // توليد فقط إذا تغيّر المسار عن المرة الأخيرة
    if (path != _lastGeneratedPath) {
      _lastGeneratedPath = path;
      _generateWaveform(path);
    }
  }

  Future<void> _generateWaveform(String path) async {
    await WaveformService.instance.generateFromFile(path);
  }

  @override
  Widget build(BuildContext context) {
    final isGenerating = WaveformService.instance.isGenerating;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF070B13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLight ? const Color(0xFFCBD5E1) : const Color(0xFF1F293D),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          StreamBuilder<Duration>(
            stream: widget.session.player.positionStream,
            builder: (context, posSnapshot) {
              final position = posSnapshot.data ?? widget.session.player.position;
              final duration = widget.session.player.duration ?? Duration.zero;

              return WaveformWidget(
                peaks: WaveformService.instance.peaks,
                position: position,
                duration: duration,
                entries: widget.session.entries,
                pendingStartMs: widget.session.pendingStartMs,
                activeType: widget.session.activeType,
                onSeek: (pos) => widget.session.player.seek(pos),
                height: 120,
              );
            },
          ),
          if (isGenerating)
            const Positioned(
              top: 8,
              right: 8,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _PositionSlider extends StatefulWidget {
  const _PositionSlider({required this.player});

  final AudioPlayer player;

  @override
  State<_PositionSlider> createState() => _PositionSliderState();
}

class _PositionSliderState extends State<_PositionSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.player.positionStream,
      builder: (BuildContext context, AsyncSnapshot<Duration> posSnap) {
        return StreamBuilder<Duration?>(
          stream: widget.player.durationStream,
          builder: (BuildContext context, AsyncSnapshot<Duration?> durSnap) {
            final double positionMs =
                (posSnap.data?.inMilliseconds ?? 0).toDouble();
            final double durationMs =
                (durSnap.data?.inMilliseconds ?? 0).toDouble();

            // نمسح قيمة السحب بعدما يلحقها المشغل حتى لا "يرتد" المؤشر.
            if (_dragValue != null &&
                durationMs > 0 &&
                (positionMs - _dragValue!).abs() < 120) {
              _dragValue = null;
            }

            final double maxValue = durationMs > 0 ? durationMs : 1.0;
            final double value =
                (_dragValue ?? positionMs).clamp(0.0, maxValue);

            return SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: value,
                max: maxValue,
                onChanged: durationMs > 0
                    ? (double v) => setState(() => _dragValue = v)
                    : null,
                onChangeEnd: (double v) {
                  widget.player.seek(Duration(milliseconds: v.round()));
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _StudioControlsBar extends StatelessWidget {
  const _StudioControlsBar({required this.session});

  final TimingSession session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // اختيار السرعة
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: TimingSession.speeds.map((double s) {
              final isSelected = session.speed == s;
              return InkWell(
                onTap: () => session.setSpeed(s),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${s == s.roundToDouble() ? s.toInt() : s}x',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // أزرار التحكم الرئيسية في المنتصف
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'keyboard.arrow_down_desc'.tr(),
              onPressed: () => session.seekRelative(-30000),
              icon: const Icon(Icons.replay_30_rounded),
            ),
            IconButton(
              tooltip: 'keyboard.arrow_left_desc'.tr(),
              onPressed: () => session.seekRelative(-5000),
              icon: const Icon(Icons.replay_5_rounded),
            ),
            const SizedBox(width: 4),
            StreamBuilder<PlayerState>(
              stream: session.player.playerStateStream,
              builder: (BuildContext context, AsyncSnapshot<PlayerState> snapshot) {
                final bool playing = snapshot.data?.playing ?? false;
                return FilledButton(
                  onPressed: () => session.togglePlayPause(),
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(14),
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                  ),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 28,
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'keyboard.arrow_right_desc'.tr(),
              onPressed: () => session.seekRelative(5000),
              icon: const Icon(Icons.forward_5_rounded),
            ),
            IconButton(
              tooltip: 'keyboard.arrow_up_desc'.tr(),
              onPressed: () => session.seekRelative(30000),
              icon: const Icon(Icons.forward_30_rounded),
            ),
          ],
        ),

        // تعويض التأخير
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'player.latency_offset'.tr(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${session.latencyOffsetMs > 0 ? "+" : ""}${session.latencyOffsetMs}ms',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: () => session.adjustLatency(-50),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.remove_rounded, size: 16),
                ),
              ),
              InkWell(
                onTap: () => session.adjustLatency(50),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.add_rounded, size: 16),
                ),
              ),
            ],
          ),
        ),

        // زر التقسيم الذكي حسب السكتات
        IconButton.filledTonal(
          tooltip: 'smart_split.tooltip'.tr(),
          style: IconButton.styleFrom(
            backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: session.hasSource ? () => _showSmartSplitDialog(context, session) : null,
          icon: Icon(Icons.auto_awesome_rounded, size: 18, color: scheme.primary),
        ),

        if (session.hasPendingStart)
          OutlinedButton.icon(
            onPressed: () => session.replayPendingStart(),
            icon: const Icon(Icons.replay_rounded, size: 16),
            label: Text('player.replay_from_start'.tr(), style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
      ],
    );
  }

  void _showSmartSplitDialog(BuildContext context, TimingSession session) {
    double threshold = 0.12;
    int minSilenceMs = 600;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final scheme = Theme.of(context).colorScheme;
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Text('smart_split.title'.tr(), style: const TextStyle(fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'smart_split.desc'.tr(),
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Text('smart_split.sensitivity'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Slider(
                    value: threshold,
                    min: 0.05,
                    max: 0.25,
                    divisions: 4,
                    label: '${(threshold * 100).toInt()}%',
                    onChanged: (v) => setDialogState(() => threshold = v),
                  ),
                  const SizedBox(height: 10),
                  Text('smart_split.min_silence'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Slider(
                    value: minSilenceMs.toDouble(),
                    min: 400,
                    max: 1500,
                    divisions: 11,
                    label: '${minSilenceMs}ms',
                    onChanged: (v) => setDialogState(() => minSilenceMs = v.round()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('common.cancel'.tr()),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  final count = session.autoGenerateFromDetectedPauses(
                    silenceThreshold: threshold,
                    minSilenceMs: minSilenceMs,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        count > 0
                            ? 'smart_split.created_count'.tr(namedArgs: {'count': count.toString()})
                            : 'smart_split.none_detected'.tr(),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.flash_on_rounded, size: 18),
                label: Text('smart_split.apply_btn'.tr()),
              ),
            ],
          );
        },
      ),
    );
  }
}

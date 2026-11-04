import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../controllers/timing_session.dart';
import '../models/timing_entry.dart';

class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.session,
    required this.onPressed,
  });

  final TimingSession session;
  final VoidCallback onPressed;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.session,
      builder: (BuildContext context, Widget? _) {
        final bool hasSource = widget.session.hasSource;
        final bool pending = widget.session.hasPendingStart;
        final ColorScheme scheme = Theme.of(context).colorScheme;
        final brightness = Theme.of(context).brightness;
        final isLight = brightness == Brightness.light;
        final activeType = widget.session.activeType;
        final typeColor = activeType.colorFor(brightness);

        const buttonHeight = 52.0;

        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, _) {
            final pulseScale = pending ? _pulseAnimation.value : 1.0;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: buttonHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: !hasSource
                    ? null
                    : pending
                        ? const LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                          )
                        : LinearGradient(
                            colors: isLight
                                ? [typeColor, typeColor.withValues(alpha: 0.88)]
                                : [typeColor.withValues(alpha: 0.92), typeColor.withValues(alpha: 0.76)],
                          ),
                color: !hasSource ? scheme.surfaceContainerHighest.withValues(alpha: 0.5) : null,
                boxShadow: pending
                    ? [
                        BoxShadow(
                          color: const Color(0xFF14B8A6).withValues(alpha: (0.35 * pulseScale).clamp(0.0, 0.6)),
                          blurRadius: 16 * pulseScale,
                          spreadRadius: 1.5 * pulseScale,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : hasSource
                        ? [
                            BoxShadow(
                              color: typeColor.withValues(alpha: isLight ? 0.28 : 0.22),
                              blurRadius: 10,
                              spreadRadius: 0.5,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                border: Border.all(
                  color: !hasSource
                      ? scheme.outlineVariant.withValues(alpha: 0.3)
                      : pending
                          ? const Color(0xFF5EEAD4).withValues(alpha: (0.45 * pulseScale).clamp(0.0, 0.8))
                          : Colors.white.withValues(alpha: isLight ? 0.3 : 0.2),
                  width: pending ? 1.5 : 1.2,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: hasSource ? widget.onPressed : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: StreamBuilder<Duration>(
                      stream: widget.session.player.positionStream,
                      builder: (context, snapshot) {
                        final currentMs = snapshot.data?.inMilliseconds ?? 0;
                        final int startMs = widget.session.pendingStartMs ?? currentMs;
                        final int elapsedMs = (currentMs - startMs).clamp(0, 3600000);

                        final foregroundColor = !hasSource
                            ? scheme.onSurface.withValues(alpha: 0.4)
                            : pending
                                ? Colors.white
                                : (isLight ? Colors.white : Colors.black87);

                        return Row(
                          children: [
                            // أيقونة الحالة الدائرية
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: !hasSource
                                    ? scheme.surfaceContainerHighest
                                    : Colors.black.withValues(alpha: 0.2),
                              ),
                              child: Icon(
                                pending
                                    ? Icons.radio_button_checked_rounded
                                    : !hasSource
                                        ? Icons.lock_outline_rounded
                                        : activeType.icon,
                                size: 19,
                                color: foregroundColor,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // نص الإجراء الرئيسي
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      !hasSource
                                          ? 'file.select_file_first'.tr()
                                          : pending
                                              ? 'recording.end_recording'.tr(namedArgs: {
                                                  'type': activeType.nameKey.tr(),
                                                  'count': widget.session.nextVerse.toString(),
                                                })
                                              : 'recording.start_recording'.tr(namedArgs: {
                                                  'type': activeType.nameKey.tr(),
                                                  'count': widget.session.nextVerse.toString(),
                                                }),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: foregroundColor,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                  if (pending) ...[
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFF5EEAD4).withValues(alpha: 0.4),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        '+${TimingEntry.formatTime(elapsedMs)}',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // شارة الاختصار المدمجة الأنيقة (Keycap) مع زر الإلغاء السريع عند التسجيل
                            if (hasSource) ...[
                              const SizedBox(width: 10),
                              if (pending) ...[
                                Tooltip(
                                  message: 'recording.cancel_tooltip'.tr(),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => widget.session.cancelPendingStart(),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.35),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(
                                              Icons.close_rounded,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            SizedBox(width: 3),
                                            Text(
                                              'Esc',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'keyboard.enter'.tr(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.keyboard_return_rounded,
                                      color: Colors.white,
                                      size: 13,
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
                ),
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../controllers/timing_session.dart';
import '../models/timing_entry.dart';

class RecordButton extends StatelessWidget {
  const RecordButton({
    super.key,
    required this.session,
    required this.onPressed,
  });

  final TimingSession session;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (BuildContext context, Widget? _) {
        final bool hasSource = session.hasSource;
        final bool pending = session.hasPendingStart;
        final ColorScheme scheme = Theme.of(context).colorScheme;
        final brightness = Theme.of(context).brightness;
        final isLight = brightness == Brightness.light;
        final activeType = session.activeType;
        final typeColor = activeType.colorFor(brightness);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: pending
                    ? [
                        BoxShadow(
                          color: scheme.error.withValues(alpha: 0.45),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: typeColor.withValues(alpha: isLight ? 0.25 : 0.2),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ],
              ),
              child: FilledButton(
                onPressed: hasSource ? onPressed : null,
                style: FilledButton.styleFrom(
                  backgroundColor: pending ? scheme.error : typeColor,
                  foregroundColor: pending
                      ? scheme.onError
                      : (isLight ? Colors.white : Colors.black87),
                  disabledBackgroundColor:
                      scheme.onSurface.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: StreamBuilder<Duration>(
                  stream: session.player.positionStream,
                  builder: (context, snapshot) {
                    final currentMs = snapshot.data?.inMilliseconds ?? 0;
                    final int startMs = session.pendingStartMs ?? currentMs;
                    final int elapsedMs =
                        (currentMs - startMs).clamp(0, 3600000);

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          pending
                              ? Icons.stop_circle_rounded
                              : activeType.icon,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          pending
                              ? 'recording.end_recording'.tr(namedArgs: {
                                  'type': activeType.nameKey.tr(),
                                  'count': session.nextVerse.toString()
                                })
                              : 'recording.start_recording'.tr(namedArgs: {
                                  'type': activeType.nameKey.tr(),
                                }),
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (pending) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+${TimingEntry.formatTime(elapsedMs)}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasSource
                  ? '${'keyboard.enter'.tr()} = ${'keyboard.enter_desc'.tr()}  •  ${'keyboard.switch_type'.tr()}  •  ${'keyboard.space'.tr()} = ${'keyboard.space_desc'.tr()}'
                  : 'file.select_file_first'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                    fontSize: 11,
                  ),
            ),
          ],
        );
      },
    );
  }
}

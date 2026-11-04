import 'dart:io' show Platform, exit;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// أزرار التحكم بالنافذة (تصغير، تكبير/استعادة، إغلاق)
/// تدمج مباشرة في شريط التطبيق العلوي (AppBar) لإلغاء الازدواجية وتوفير المساحة
class DesktopWindowControls extends StatefulWidget {
  const DesktopWindowControls({super.key, this.height = 40});

  final double height;

  static bool get isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  State<DesktopWindowControls> createState() => _DesktopWindowControlsState();
}

class _DesktopWindowControlsState extends State<DesktopWindowControls> {
  bool _isMaximized = false;
  ListenerId? _listenerId;

  Window? get _currentWindow {
    try {
      final cur = WindowManager.instance.getCurrent();
      if (cur != null) return cur;
      final all = WindowManager.instance.getAll();
      if (all.isNotEmpty) return all.first;
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (DesktopWindowControls.isSupported) {
      _initWindow();
    }
  }

  void _initWindow() {
    try {
      final win = _currentWindow;
      if (win != null) {
        _isMaximized = win.isMaximized;
      }
      _listenerId = WindowManager.instance.addListener((event) {
        switch (event) {
          case WindowMaximizedEvent():
          case WindowRestoredEvent():
          case WindowResizedEvent():
            final max = _currentWindow?.isMaximized ?? false;
            if (mounted && _isMaximized != max) {
              setState(() => _isMaximized = max);
            }
          default:
            break;
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_listenerId != null) {
      try {
        WindowManager.instance.removeListener(_listenerId!);
      } catch (_) {}
    }
    super.dispose();
  }

  void _minimize() {
    try {
      final win = _currentWindow;
      win?.minimize();
    } catch (_) {}
  }

  void _close() {
    final win = _currentWindow;
    try {
      final closed = win?.close() ?? false;
      if (!closed) {
        exit(0);
      }
    } catch (_) {
      exit(0);
    }
  }

  void _toggleMaximize() {
    final win = _currentWindow;
    if (win == null) return;
    if (win.isMaximized) {
      win.unmaximize();
      if (mounted) setState(() => _isMaximized = false);
    } else {
      win.maximize();
      if (mounted) setState(() => _isMaximized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!DesktopWindowControls.isSupported) {
      return const SizedBox.shrink();
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _WindowControlButton(
            icon: Icons.remove_rounded,
            height: widget.height,
            onTap: _minimize,
          ),
          const SizedBox(width: 2),
          MaximizeButtonArea(
            window: _currentWindow,
            child: _WindowControlButton(
              icon: _isMaximized ? Icons.crop_16_9_rounded : Icons.crop_square_rounded,
              height: widget.height,
              onTap: _toggleMaximize,
            ),
          ),
          const SizedBox(width: 2),
          _WindowControlButton(
            icon: Icons.close_rounded,
            height: widget.height,
            isClose: true,
            onTap: _close,
          ),
        ],
      ),
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  const _WindowControlButton({
    required this.icon,
    required this.height,
    required this.onTap,
    this.isClose = false,
  });

  final IconData icon;
  final double height;
  final VoidCallback onTap;
  final bool isClose;

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Color bg;
    Color iconColor;

    if (widget.isClose) {
      bg = _isHovered ? const Color(0xFFE81123) : Colors.transparent;
      iconColor = _isHovered ? Colors.white : scheme.onSurfaceVariant;
    } else {
      bg = _isHovered
          ? scheme.onSurface.withValues(alpha: 0.1)
          : Colors.transparent;
      iconColor = scheme.onSurfaceVariant;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 44,
          height: widget.height,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 16, color: iconColor),
        ),
      ),
    );
  }
}


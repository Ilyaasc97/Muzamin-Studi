// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('settings.title'.tr()),
        centerTitle: false,
        actions: [
          TextButton.icon(
            onPressed: _resetAllToDefaults,
            icon: const Icon(Icons.restore_rounded, size: 18),
            label: Text('settings.reset_all'.tr()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // قسم المظهر والثيم
              _buildSectionCard(
                context,
                title: 'settings.appearance'.tr(),
                icon: Icons.palette_outlined,
                child: _buildThemeSelector(context),
              ),
              const SizedBox(height: 16),

              // قسم تعويض زمن الاستجابة
              _buildSectionCard(
                context,
                title: 'settings.latency_offset'.tr(),
                icon: Icons.timer_outlined,
                child: _buildLatencyTuner(context),
              ),
              const SizedBox(height: 16),

              // قسم اختصارات لوحة المفاتيح
              _buildSectionCard(
                context,
                title: 'settings.shortcuts_title'.tr(),
                icon: Icons.keyboard_outlined,
                trailing: TextButton.icon(
                  onPressed: _resetShortcutsToDefaults,
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: Text('settings.reset_shortcuts'.tr()),
                ),
                child: _buildShortcutsList(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    Widget? trailing,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: scheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing,
                ],
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    final currentTheme = SettingsService.instance.themeMode;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 450;
        final options = [
          (
            ThemeMode.dark,
            'settings.theme_dark'.tr(),
            Icons.dark_mode_rounded,
            'settings.theme_dark_desc'.tr(),
          ),
          (
            ThemeMode.light,
            'settings.theme_light'.tr(),
            Icons.light_mode_rounded,
            'settings.theme_light_desc'.tr(),
          ),
          (
            ThemeMode.system,
            'settings.theme_system'.tr(),
            Icons.brightness_auto_rounded,
            'settings.theme_system_desc'.tr(),
          ),
        ];

        if (isNarrow) {
          return Column(
            children: options.map((opt) {
              final isSelected = currentTheme == opt.$1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildThemeTile(
                  context,
                  mode: opt.$1,
                  title: opt.$2,
                  desc: opt.$4,
                  icon: opt.$3,
                  isSelected: isSelected,
                ),
              );
            }).toList(),
          );
        }

        return Row(
          children: options.map((opt) {
            final isSelected = currentTheme == opt.$1;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildThemeTile(
                  context,
                  mode: opt.$1,
                  title: opt.$2,
                  desc: opt.$4,
                  icon: opt.$3,
                  isSelected: isSelected,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildThemeTile(
    BuildContext context, {
    required ThemeMode mode,
    required String title,
    required String desc,
    required IconData icon,
    required bool isSelected,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        SettingsService.instance.setThemeMode(mode);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer.withValues(alpha: 0.3)
              : scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? scheme.primary : Theme.of(context).hintColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? scheme.primary : null,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: scheme.primary, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatencyTuner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latency = SettingsService.instance.latencyOffsetMs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'settings.latency_hint'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${latency > 0 ? '+$latency' : latency} ms',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: '-50 ms',
              onPressed: () {
                SettingsService.instance.setLatencyOffsetMs(latency - 50);
              },
              icon: const Icon(Icons.remove_rounded, size: 18),
            ),
            Expanded(
              child: Slider(
                value: latency.toDouble(),
                min: -1000,
                max: 1000,
                divisions: 40,
                label: '$latency ms',
                onChanged: (value) {
                  SettingsService.instance.setLatencyOffsetMs(value.round());
                },
              ),
            ),
            IconButton.filledTonal(
              tooltip: '+50 ms',
              onPressed: () {
                SettingsService.instance.setLatencyOffsetMs(latency + 50);
              },
              icon: const Icon(Icons.add_rounded, size: 18),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShortcutsList(BuildContext context) {
    final settings = SettingsService.instance;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Column(
          children: SettingsService.shortcutKeys.map((action) {
            final currentKey = settings.shortcuts[action] ??
                settings.defaultShortcuts[action] ??
                '';
            final actionKey = SettingsService.getActionKey(action);
            final fallback = SettingsService.shortcutLabels[action] ?? action;
            final label = actionKey.tr() != actionKey ? actionKey.tr() : fallback;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                onTap: () => _showShortcutPickerDialog(action),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          settings.formatKeyForDisplay(currentKey),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Theme.of(context).hintColor,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _showShortcutPickerDialog(String action) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _ShortcutPickerDialog(
        action: action,
        currentKey: SettingsService.instance.shortcuts[action] ??
            SettingsService.instance.defaultShortcuts[action] ??
            '',
      ),
    );

    if (result != null &&
        result != SettingsService.instance.shortcuts[action]) {
      await SettingsService.instance.setShortcut(action, result);
    }
  }

  void _resetShortcutsToDefaults() async {
    await SettingsService.instance.resetShortcutsToDefault();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.reset_shortcuts_success'.tr())),
      );
    }
  }

  void _resetAllToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.reset_all_title'.tr()),
        content: Text('settings.reset_all_warning'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('settings.restore_all'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SettingsService.instance.resetShortcutsToDefault();
      await SettingsService.instance.setThemeMode(ThemeMode.dark);
      await SettingsService.instance.setLatencyOffsetMs(0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('settings.reset_all_success'.tr())),
        );
      }
    }
  }
}

class _ShortcutPickerDialog extends StatefulWidget {
  final String action;
  final String currentKey;

  const _ShortcutPickerDialog({
    required this.action,
    required this.currentKey,
  });

  @override
  State<_ShortcutPickerDialog> createState() => _ShortcutPickerDialogState();
}

class _ShortcutPickerDialogState extends State<_ShortcutPickerDialog> {
  late String _capturedKey;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _capturedKey = widget.currentKey;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isShiftPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      Navigator.pop(context);
      return;
    }

    if (key == LogicalKeyboardKey.backspace &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isShiftPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      setState(() => _capturedKey = '');
      return;
    }

    if (key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      return;
    }

    final List<String> parts = [];
    if (HardwareKeyboard.instance.isControlPressed) parts.add('Control');
    if (HardwareKeyboard.instance.isAltPressed) parts.add('Alt');
    if (HardwareKeyboard.instance.isShiftPressed) parts.add('Shift');
    if (HardwareKeyboard.instance.isMetaPressed) parts.add('Meta');

    String keyName = _getLogicalKeyName(key);
    parts.add(keyName);

    setState(() {
      _capturedKey = parts.join('+');
    });
  }

  String _getLogicalKeyName(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.numpadEnter) return 'NumpadEnter';
    if (key == LogicalKeyboardKey.arrowRight) return 'ArrowRight';
    if (key == LogicalKeyboardKey.arrowLeft) return 'ArrowLeft';
    if (key == LogicalKeyboardKey.arrowUp) return 'ArrowUp';
    if (key == LogicalKeyboardKey.arrowDown) return 'ArrowDown';
    if (key == LogicalKeyboardKey.escape) return 'Escape';
    if (key == LogicalKeyboardKey.delete) return 'Delete';
    if (key == LogicalKeyboardKey.home) return 'Home';
    if (key == LogicalKeyboardKey.end) return 'End';
    if (key == LogicalKeyboardKey.pageUp) return 'PageUp';
    if (key == LogicalKeyboardKey.pageDown) return 'PageDown';
    if (key == LogicalKeyboardKey.tab) return 'Tab';

    final keyLabel = key.keyLabel;
    if (keyLabel.isNotEmpty) {
      return keyLabel.toUpperCase();
    }
    return key.debugName ?? 'Key';
  }

  @override
  Widget build(BuildContext context) {
    final actionKey = SettingsService.getActionKey(widget.action);
    final fallback =
        SettingsService.shortcutLabels[widget.action] ?? widget.action;
    final actionName = actionKey.tr() != actionKey ? actionKey.tr() : fallback;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: AlertDialog(
        title: Text('${'settings.change_shortcut'.tr()}: $actionName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'settings.press_keys_prompt'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.keyboard_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    SettingsService.instance.formatKeyForDisplay(_capturedKey),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'settings.shortcut_dialog_hint'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: _capturedKey.isEmpty
                ? null
                : () => Navigator.pop(context, _capturedKey),
            child: Text('settings.save'.tr()),
          ),
        ],
      ),
    );
  }
}

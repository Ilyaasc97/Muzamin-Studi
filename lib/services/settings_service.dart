// lib/services/settings_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _prefsKeyShortcuts = 'keyboard_shortcuts';
  static const _prefsKeyThemeMode = 'theme_mode';
  static const _prefsKeyLatencyOffset = 'latency_offset_ms';

  // Default keyboard shortcuts
  static const Map<String, String> _defaultShortcuts = {
    'play_pause': 'Space',
    'mark_verse': 'Enter',
    'seek_forward_5s': 'ArrowRight',
    'seek_backward_5s': 'ArrowLeft',
    'seek_forward_30s': 'ArrowUp',
    'seek_backward_30s': 'ArrowDown',
    'cancel_pending': 'Escape',
    'undo': 'Control+Z',
    'delete_all': 'Delete',
  };

  /// Default keyboard shortcuts (exposed for use by UI)
  Map<String, String> get defaultShortcuts => _defaultShortcuts;

  // List of shortcut keys used in the code
  static const List<String> shortcutKeys = [
    'play_pause',
    'mark_verse',
    'seek_forward_5s',
    'seek_backward_5s',
    'seek_forward_30s',
    'seek_backward_30s',
    'cancel_pending',
    'undo',
    'delete_all',
  ];

  // Translation key for shortcut action
  static String getActionKey(String action) => 'settings.actions.$action';

  // Display names for shortcuts (fallback)
  static const Map<String, String> shortcutLabels = {
    'play_pause': 'تشغيل / إيقاف مؤقت',
    'mark_verse': 'تسجيل بداية/نهاية الآية',
    'seek_forward_5s': 'تقديم 5 ثوانٍ',
    'seek_backward_5s': 'تأخير 5 ثوانٍ',
    'seek_forward_30s': 'تقديم 30 ثانية',
    'seek_backward_30s': 'تأخير 30 ثانية',
    'cancel_pending': 'إلغاء بداية قيد التسجيل',
    'undo': 'تراجع عن آخر إدخال (Undo)',
    'delete_all': 'حذف جميع التوقيتات',
  };

  SharedPreferences? _prefs;
  Map<String, String> _shortcuts = {};
  ThemeMode _themeMode = ThemeMode.dark;
  int _latencyOffsetMs = 0;

  Map<String, String> get shortcuts => Map.unmodifiable(_shortcuts);
  ThemeMode get themeMode => _themeMode;
  int get latencyOffsetMs => _latencyOffsetMs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> initialize() async {
    final prefs = await _getPrefs();

    // Load shortcuts
    final shortcutsJson = prefs.getString(_prefsKeyShortcuts);
    if (shortcutsJson != null) {
      try {
        final Map<String, dynamic> decoded = Map<String, dynamic>.from(
            Map<String, dynamic>.from(json.decode(shortcutsJson)));
        _shortcuts = decoded.map((k, v) => MapEntry(k, v as String));
      } catch (_) {
        _shortcuts = Map.from(_defaultShortcuts);
      }
    } else {
      _shortcuts = Map.from(_defaultShortcuts);
    }

    // Fill in missing keys
    for (final key in _defaultShortcuts.keys) {
      _shortcuts.putIfAbsent(key, () => _defaultShortcuts[key]!);
    }

    // Load theme
    final themeIndex = prefs.getInt(_prefsKeyThemeMode);
    _themeMode = themeIndex != null
        ? ThemeMode.values[themeIndex.clamp(0, ThemeMode.values.length - 1)]
        : ThemeMode.dark;

    // Load latency offset
    _latencyOffsetMs = prefs.getInt(_prefsKeyLatencyOffset) ?? 0;

    notifyListeners();
  }

  Future<void> setShortcut(String action, String key) async {
    _shortcuts[action] = key;
    notifyListeners();
    await _saveShortcuts();
  }

  Future<void> resetShortcutsToDefault() async {
    _shortcuts = Map.from(_defaultShortcuts);
    notifyListeners();
    await _saveShortcuts();
  }

  Future<void> _saveShortcuts() async {
    final prefs = await _getPrefs();
    await prefs.setString(_prefsKeyShortcuts, json.encode(_shortcuts));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.setInt(_prefsKeyThemeMode, ThemeMode.values.indexOf(mode));
  }

  Future<void> setLatencyOffsetMs(int offset) async {
    _latencyOffsetMs = offset.clamp(-1000, 1000);
    notifyListeners();
    try {
      final prefs = await _getPrefs();
      await prefs.setInt(_prefsKeyLatencyOffset, _latencyOffsetMs);
    } catch (_) {}
  }

  String getShortcutDisplay(String action) {
    final key = _shortcuts[action] ?? _defaultShortcuts[action] ?? '';
    return formatKeyForDisplay(key);
  }

  String formatKeyForDisplay(String key) {
    return key
        .replaceAll('Control', 'Ctrl')
        .replaceAll('Alt', 'Alt')
        .replaceAll('Shift', 'Shift')
        .replaceAll('Meta', 'Meta')
        .replaceAll('ArrowUp', '↑')
        .replaceAll('ArrowDown', '↓')
        .replaceAll('ArrowLeft', '←')
        .replaceAll('ArrowRight', '→')
        .replaceAll('Space', 'Space')
        .replaceAll('Enter', 'Enter')
        .replaceAll('Escape', 'Esc')
        .replaceAll('Delete', 'Del');
  }
}
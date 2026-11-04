import 'dart:collection';
import 'package:flutter/foundation.dart';

enum LogLevel { info, warn, error }

class LogRecord {
  const LogRecord({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  @override
  String toString() {
    final String timeStr = timestamp.toIso8601String();
    final String prefix = '[${level.name.toUpperCase()}][$timeStr]';
    if (error != null) {
      return '$prefix $message (Error: $error)';
    }
    return '$prefix $message';
  }
}

/// خدمة تسجيل غير حظرية وخفيفة الوزن تدعم التتبع والتشخيص
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const int _maxBufferSize = 100;
  final Queue<LogRecord> _buffer = Queue<LogRecord>();

  List<LogRecord> get logs => List<LogRecord>.unmodifiable(_buffer);

  void info(String message) => _log(LogLevel.info, message);

  void warn(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.warn, message, error, stackTrace);

  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.error, message, error, stackTrace);

  void _log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final record = LogRecord(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    if (_buffer.length >= _maxBufferSize) {
      _buffer.removeFirst();
    }
    _buffer.addLast(record);

    if (kDebugMode) {
      debugPrint(record.toString());
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
  }

  void clear() {
    _buffer.clear();
  }
}

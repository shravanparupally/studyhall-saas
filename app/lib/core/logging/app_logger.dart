import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_logger.g.dart';

/// Log severity, ordered least to most severe.
enum LogLevel {
  /// Verbose detail useful only during active development.
  debug,

  /// A notable event under normal operation.
  info,

  /// A caught, non-fatal problem worth investigating.
  warning,

  /// A caught failure that affected the current operation.
  error,
}

/// The structured shape every log call carries, per
/// docs/15_Technical_Architecture.md §15.18. Fields are nullable because
/// not every call site has Organization/Branch/actor context (e.g. a
/// bootstrap-time log emitted before sign-in) — omission is honest, never
/// backfilled with a placeholder value.
///
/// Never put PII (phone numbers, names, ID document references) in a log
/// call's action string or any field here — same rule as
/// Crashlytics/Analytics, restated per §15.18.
@immutable
class LogContext {
  /// Creates a structured logging context. Every field is optional.
  const LogContext({
    this.organizationId,
    this.branchId,
    this.actorId,
    this.latencyMs,
  });

  /// The tenant this log entry concerns, if known.
  final String? organizationId;

  /// The Branch this log entry concerns, if known.
  final String? branchId;

  /// The user or system job that triggered this log entry, if known.
  final String? actorId;

  /// How long the logged operation took, in milliseconds, if timed.
  final int? latencyMs;

  /// This context's fields as a map, omitting anything unset.
  Map<String, Object?> toMap() => {
    if (organizationId != null) 'organizationId': organizationId,
    if (branchId != null) 'branchId': branchId,
    if (actorId != null) 'actorId': actorId,
    if (latencyMs != null) 'latencyMs': latencyMs,
  };
}

/// The shared logging utility mandated by §15.18 — every log call, client
/// or server-facing Dart code, goes through this instead of ad hoc
/// `print`/`debugPrint`. Debug-level logs are compiled out of release
/// builds entirely via [kDebugMode], not just filtered at runtime.
class AppLogger {
  /// Creates a logger. Stateless — safe to construct freely or share.
  const AppLogger();

  /// Logs verbose detail, compiled out of release builds.
  void debug(String action, {LogContext? context}) {
    if (kDebugMode) _log(LogLevel.debug, action, context: context);
  }

  /// Logs a notable event under normal operation.
  void info(String action, {LogContext? context}) {
    _log(LogLevel.info, action, context: context);
  }

  /// Logs a caught, non-fatal problem worth investigating.
  void warning(String action, {LogContext? context}) {
    _log(LogLevel.warning, action, context: context);
  }

  /// Logs a caught failure, with the originating error and stack trace.
  void error(
    String action, {
    LogContext? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.error,
      action,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _log(
    LogLevel level,
    String action, {
    LogContext? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = <String, Object?>{'action': action, ...?context?.toMap()};
    developer.log(
      entry.toString(),
      name: 'studyhall',
      level: _severity(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  int _severity(LogLevel level) => switch (level) {
    LogLevel.debug => 500,
    LogLevel.info => 800,
    LogLevel.warning => 900,
    LogLevel.error => 1000,
  };
}

/// The composition-root provider for [AppLogger] — depend on this rather
/// than constructing an `AppLogger` directly, per
/// docs/15_Technical_Architecture.md §15.16.
@riverpod
AppLogger appLogger(Ref ref) => const AppLogger();

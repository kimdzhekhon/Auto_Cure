import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks error pattern frequency and fix success rates to improve
/// the agent's confidence scoring over time.
class ErrorPatternDatabase extends ChangeNotifier {
  static const _key = 'autocure_error_patterns';
  final _log = Logger('ErrorPatternDB');
  final Map<String, PatternStats> _patterns = {};

  Map<String, PatternStats> get patterns => Map.unmodifiable(_patterns);

  /// Record an error occurrence.
  void recordError(String errorType) {
    final stats = _patterns.putIfAbsent(
      errorType,
      () => PatternStats(errorType: errorType),
    );
    _patterns[errorType] = stats.copyWith(
      occurrences: stats.occurrences + 1,
      lastSeen: DateTime.now(),
    );
    notifyListeners();
    _persist();
  }

  /// Record a fix attempt result.
  void recordFixAttempt({
    required String errorType,
    required String strategy,
    required bool success,
    required Duration duration,
  }) {
    final stats = _patterns.putIfAbsent(
      errorType,
      () => PatternStats(errorType: errorType),
    );

    final strategyStats = Map<String, StrategyRecord>.from(stats.strategies);
    final existing = strategyStats[strategy] ??
        StrategyRecord(strategy: strategy);

    strategyStats[strategy] = existing.copyWith(
      attempts: existing.attempts + 1,
      successes: existing.successes + (success ? 1 : 0),
      totalDuration: existing.totalDuration + duration,
    );

    _patterns[errorType] = stats.copyWith(
      fixAttempts: stats.fixAttempts + 1,
      fixSuccesses: stats.fixSuccesses + (success ? 1 : 0),
      strategies: strategyStats,
    );
    notifyListeners();
    _persist();
  }

  /// Get the best strategy for a given error type based on historical data.
  String? bestStrategy(String errorType) {
    final stats = _patterns[errorType];
    if (stats == null || stats.strategies.isEmpty) return null;

    String? best;
    double bestRate = -1;

    for (final entry in stats.strategies.entries) {
      final rate = entry.value.successRate;
      if (rate > bestRate && entry.value.attempts >= 2) {
        bestRate = rate;
        best = entry.key;
      }
    }
    return best;
  }

  /// Get an adjusted confidence score based on historical success rate.
  double adjustedConfidence(String errorType, double baseConfidence) {
    final stats = _patterns[errorType];
    if (stats == null || stats.fixAttempts < 3) return baseConfidence;

    final historicalRate = stats.fixSuccesses / stats.fixAttempts;
    // Weighted average: 60% base analysis, 40% historical data
    return baseConfidence * 0.6 + historicalRate * 0.4;
  }

  /// Get top N most frequent error types.
  List<MapEntry<String, PatternStats>> topErrors({int limit = 10}) {
    final sorted = _patterns.entries.toList()
      ..sort((a, b) => b.value.occurrences.compareTo(a.value.occurrences));
    return sorted.take(limit).toList();
  }

  /// Load from SharedPreferences.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _patterns.clear();
      for (final entry in data.entries) {
        _patterns[entry.key] = PatternStats.fromJson(
            entry.value as Map<String, dynamic>);
      }
      _log.info('Loaded ${_patterns.length} error patterns');
      notifyListeners();
    } catch (e) {
      _log.warning('Failed to load error patterns: $e');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _patterns.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_key, jsonEncode(data));
  }

  Future<void> clear() async {
    _patterns.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    notifyListeners();
  }
}

/// Statistics for a single error pattern.
class PatternStats {
  final String errorType;
  final int occurrences;
  final int fixAttempts;
  final int fixSuccesses;
  final DateTime? firstSeen;
  final DateTime? lastSeen;
  final Map<String, StrategyRecord> strategies;

  PatternStats({
    required this.errorType,
    this.occurrences = 0,
    this.fixAttempts = 0,
    this.fixSuccesses = 0,
    this.firstSeen,
    this.lastSeen,
    this.strategies = const {},
  });

  double get successRate =>
      fixAttempts > 0 ? fixSuccesses / fixAttempts : 0.0;

  PatternStats copyWith({
    int? occurrences,
    int? fixAttempts,
    int? fixSuccesses,
    DateTime? firstSeen,
    DateTime? lastSeen,
    Map<String, StrategyRecord>? strategies,
  }) =>
      PatternStats(
        errorType: errorType,
        occurrences: occurrences ?? this.occurrences,
        fixAttempts: fixAttempts ?? this.fixAttempts,
        fixSuccesses: fixSuccesses ?? this.fixSuccesses,
        firstSeen: firstSeen ?? this.firstSeen ?? DateTime.now(),
        lastSeen: lastSeen ?? this.lastSeen,
        strategies: strategies ?? this.strategies,
      );

  Map<String, dynamic> toJson() => {
        'errorType': errorType,
        'occurrences': occurrences,
        'fixAttempts': fixAttempts,
        'fixSuccesses': fixSuccesses,
        'firstSeen': firstSeen?.toIso8601String(),
        'lastSeen': lastSeen?.toIso8601String(),
        'strategies':
            strategies.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory PatternStats.fromJson(Map<String, dynamic> json) => PatternStats(
        errorType: json['errorType'] as String,
        occurrences: json['occurrences'] as int? ?? 0,
        fixAttempts: json['fixAttempts'] as int? ?? 0,
        fixSuccesses: json['fixSuccesses'] as int? ?? 0,
        firstSeen: json['firstSeen'] != null
            ? DateTime.parse(json['firstSeen'] as String)
            : null,
        lastSeen: json['lastSeen'] != null
            ? DateTime.parse(json['lastSeen'] as String)
            : null,
        strategies: (json['strategies'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(
                  k, StrategyRecord.fromJson(v as Map<String, dynamic>)),
            ) ??
            {},
      );
}

/// Track success/failure per fix strategy.
class StrategyRecord {
  final String strategy;
  final int attempts;
  final int successes;
  final Duration totalDuration;

  StrategyRecord({
    required this.strategy,
    this.attempts = 0,
    this.successes = 0,
    this.totalDuration = Duration.zero,
  });

  double get successRate => attempts > 0 ? successes / attempts : 0.0;
  Duration get avgDuration =>
      attempts > 0 ? totalDuration ~/ attempts : Duration.zero;

  StrategyRecord copyWith({
    int? attempts,
    int? successes,
    Duration? totalDuration,
  }) =>
      StrategyRecord(
        strategy: strategy,
        attempts: attempts ?? this.attempts,
        successes: successes ?? this.successes,
        totalDuration: totalDuration ?? this.totalDuration,
      );

  Map<String, dynamic> toJson() => {
        'strategy': strategy,
        'attempts': attempts,
        'successes': successes,
        'totalDurationMs': totalDuration.inMilliseconds,
      };

  factory StrategyRecord.fromJson(Map<String, dynamic> json) =>
      StrategyRecord(
        strategy: json['strategy'] as String,
        attempts: json['attempts'] as int? ?? 0,
        successes: json['successes'] as int? ?? 0,
        totalDuration: Duration(
            milliseconds: json['totalDurationMs'] as int? ?? 0),
      );
}

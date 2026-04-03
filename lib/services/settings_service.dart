import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted settings for the AutoCure agent.
class AgentSettings {
  final String? vmServiceUri;
  final String? githubToken;
  final String? repoOwner;
  final String? repoName;
  final String baseBranch;
  final String? ciWebhookUrl;
  final bool autoFixEnabled;
  final bool autoCreatePR;
  final int maxConcurrentFixes;
  final double minConfidenceThreshold;
  final bool notificationsEnabled;
  final bool soundEnabled;
  final int errorRetentionDays;
  final int fixRetentionDays;
  final bool darkMode;
  final List<String> ignoredErrorPatterns;
  final Duration healthCheckInterval;
  final int maxReconnectAttempts;

  const AgentSettings({
    this.vmServiceUri,
    this.githubToken,
    this.repoOwner,
    this.repoName,
    this.baseBranch = 'main',
    this.ciWebhookUrl,
    this.autoFixEnabled = true,
    this.autoCreatePR = true,
    this.maxConcurrentFixes = 1,
    this.minConfidenceThreshold = 0.6,
    this.notificationsEnabled = true,
    this.soundEnabled = false,
    this.errorRetentionDays = 30,
    this.fixRetentionDays = 90,
    this.darkMode = false,
    this.ignoredErrorPatterns = const [],
    this.healthCheckInterval = const Duration(seconds: 30),
    this.maxReconnectAttempts = 5,
  });

  AgentSettings copyWith({
    String? vmServiceUri,
    String? githubToken,
    String? repoOwner,
    String? repoName,
    String? baseBranch,
    String? ciWebhookUrl,
    bool? autoFixEnabled,
    bool? autoCreatePR,
    int? maxConcurrentFixes,
    double? minConfidenceThreshold,
    bool? notificationsEnabled,
    bool? soundEnabled,
    int? errorRetentionDays,
    int? fixRetentionDays,
    bool? darkMode,
    List<String>? ignoredErrorPatterns,
    Duration? healthCheckInterval,
    int? maxReconnectAttempts,
  }) =>
      AgentSettings(
        vmServiceUri: vmServiceUri ?? this.vmServiceUri,
        githubToken: githubToken ?? this.githubToken,
        repoOwner: repoOwner ?? this.repoOwner,
        repoName: repoName ?? this.repoName,
        baseBranch: baseBranch ?? this.baseBranch,
        ciWebhookUrl: ciWebhookUrl ?? this.ciWebhookUrl,
        autoFixEnabled: autoFixEnabled ?? this.autoFixEnabled,
        autoCreatePR: autoCreatePR ?? this.autoCreatePR,
        maxConcurrentFixes: maxConcurrentFixes ?? this.maxConcurrentFixes,
        minConfidenceThreshold:
            minConfidenceThreshold ?? this.minConfidenceThreshold,
        notificationsEnabled:
            notificationsEnabled ?? this.notificationsEnabled,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        errorRetentionDays: errorRetentionDays ?? this.errorRetentionDays,
        fixRetentionDays: fixRetentionDays ?? this.fixRetentionDays,
        darkMode: darkMode ?? this.darkMode,
        ignoredErrorPatterns:
            ignoredErrorPatterns ?? this.ignoredErrorPatterns,
        healthCheckInterval:
            healthCheckInterval ?? this.healthCheckInterval,
        maxReconnectAttempts:
            maxReconnectAttempts ?? this.maxReconnectAttempts,
      );

  Map<String, dynamic> toJson() => {
        'vmServiceUri': vmServiceUri,
        'githubToken': githubToken,
        'repoOwner': repoOwner,
        'repoName': repoName,
        'baseBranch': baseBranch,
        'ciWebhookUrl': ciWebhookUrl,
        'autoFixEnabled': autoFixEnabled,
        'autoCreatePR': autoCreatePR,
        'maxConcurrentFixes': maxConcurrentFixes,
        'minConfidenceThreshold': minConfidenceThreshold,
        'notificationsEnabled': notificationsEnabled,
        'soundEnabled': soundEnabled,
        'errorRetentionDays': errorRetentionDays,
        'fixRetentionDays': fixRetentionDays,
        'darkMode': darkMode,
        'ignoredErrorPatterns': ignoredErrorPatterns,
        'healthCheckIntervalSeconds': healthCheckInterval.inSeconds,
        'maxReconnectAttempts': maxReconnectAttempts,
      };

  factory AgentSettings.fromJson(Map<String, dynamic> json) => AgentSettings(
        vmServiceUri: json['vmServiceUri'] as String?,
        githubToken: json['githubToken'] as String?,
        repoOwner: json['repoOwner'] as String?,
        repoName: json['repoName'] as String?,
        baseBranch: json['baseBranch'] as String? ?? 'main',
        ciWebhookUrl: json['ciWebhookUrl'] as String?,
        autoFixEnabled: json['autoFixEnabled'] as bool? ?? true,
        autoCreatePR: json['autoCreatePR'] as bool? ?? true,
        maxConcurrentFixes: json['maxConcurrentFixes'] as int? ?? 1,
        minConfidenceThreshold:
            (json['minConfidenceThreshold'] as num?)?.toDouble() ?? 0.6,
        notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
        soundEnabled: json['soundEnabled'] as bool? ?? false,
        errorRetentionDays: json['errorRetentionDays'] as int? ?? 30,
        fixRetentionDays: json['fixRetentionDays'] as int? ?? 90,
        darkMode: json['darkMode'] as bool? ?? false,
        ignoredErrorPatterns: List<String>.from(
            json['ignoredErrorPatterns'] as List? ?? []),
        healthCheckInterval: Duration(
            seconds: json['healthCheckIntervalSeconds'] as int? ?? 30),
        maxReconnectAttempts: json['maxReconnectAttempts'] as int? ?? 5,
      );
}

/// Service that persists and loads agent settings.
class SettingsService extends ChangeNotifier {
  static const _key = 'autocure_settings';
  AgentSettings _settings = const AgentSettings();
  bool _loaded = false;

  AgentSettings get settings => _settings;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      _settings = AgentSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(AgentSettings settings) async {
    _settings = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
    notifyListeners();
  }

  Future<void> reset() async {
    _settings = const AgentSettings();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    notifyListeners();
  }
}

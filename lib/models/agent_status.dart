import 'error_report.dart';
import 'fix_record.dart';

/// Overall status of the self-healing agent system.
class AgentStatus {
  final AgentState state;
  final DateTime startedAt;
  final DateTime lastHeartbeat;
  final int totalErrorsDetected;
  final int totalFixesApplied;
  final int totalFixesVerified;
  final int totalPRsCreated;
  final List<ErrorReport> recentErrors;
  final List<FixRecord> recentFixes;
  final String? currentTask;
  final double successRate;
  final bool vmServiceConnected;
  final bool mcpServerRunning;

  AgentStatus({
    required this.state,
    required this.startedAt,
    required this.lastHeartbeat,
    this.totalErrorsDetected = 0,
    this.totalFixesApplied = 0,
    this.totalFixesVerified = 0,
    this.totalPRsCreated = 0,
    this.recentErrors = const [],
    this.recentFixes = const [],
    this.currentTask,
    this.successRate = 0.0,
    this.vmServiceConnected = false,
    this.mcpServerRunning = false,
  });

  AgentStatus copyWith({
    AgentState? state,
    DateTime? lastHeartbeat,
    int? totalErrorsDetected,
    int? totalFixesApplied,
    int? totalFixesVerified,
    int? totalPRsCreated,
    List<ErrorReport>? recentErrors,
    List<FixRecord>? recentFixes,
    String? currentTask,
    double? successRate,
    bool? vmServiceConnected,
    bool? mcpServerRunning,
  }) =>
      AgentStatus(
        state: state ?? this.state,
        startedAt: startedAt,
        lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
        totalErrorsDetected: totalErrorsDetected ?? this.totalErrorsDetected,
        totalFixesApplied: totalFixesApplied ?? this.totalFixesApplied,
        totalFixesVerified: totalFixesVerified ?? this.totalFixesVerified,
        totalPRsCreated: totalPRsCreated ?? this.totalPRsCreated,
        recentErrors: recentErrors ?? this.recentErrors,
        recentFixes: recentFixes ?? this.recentFixes,
        currentTask: currentTask ?? this.currentTask,
        successRate: successRate ?? this.successRate,
        vmServiceConnected: vmServiceConnected ?? this.vmServiceConnected,
        mcpServerRunning: mcpServerRunning ?? this.mcpServerRunning,
      );

  Map<String, dynamic> toJson() => {
        'state': state.name,
        'startedAt': startedAt.toIso8601String(),
        'lastHeartbeat': lastHeartbeat.toIso8601String(),
        'totalErrorsDetected': totalErrorsDetected,
        'totalFixesApplied': totalFixesApplied,
        'totalFixesVerified': totalFixesVerified,
        'totalPRsCreated': totalPRsCreated,
        'currentTask': currentTask,
        'successRate': successRate,
        'vmServiceConnected': vmServiceConnected,
        'mcpServerRunning': mcpServerRunning,
      };
}

enum AgentState {
  idle,
  monitoring,
  analyzing,
  fixing,
  verifying,
  creatingPR,
  error,
  stopped,
}

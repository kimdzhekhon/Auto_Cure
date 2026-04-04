import 'dart:async';
import 'package:logging/logging.dart';

import '../models/agent_status.dart';
import 'notification_service.dart';

/// Diagnostic info from a health check.
class HealthCheckResult {
  final bool vmServiceHealthy;
  final bool mcpServerHealthy;
  final bool agentResponsive;
  final Duration latency;
  final DateTime checkedAt;
  final List<String> warnings;

  const HealthCheckResult({
    required this.vmServiceHealthy,
    required this.mcpServerHealthy,
    required this.agentResponsive,
    required this.latency,
    required this.checkedAt,
    this.warnings = const [],
  });

  bool get allHealthy =>
      vmServiceHealthy && mcpServerHealthy && agentResponsive;

  @override
  String toString() =>
      'HealthCheck(vm: $vmServiceHealthy, mcp: $mcpServerHealthy, '
      'agent: $agentResponsive, latency: ${latency.inMilliseconds}ms)';
}

/// Periodically checks the health of the agent's subsystems.
class HealthCheckService {
  final _log = Logger('HealthCheckService');
  final NotificationService? _notifications;
  Timer? _timer;
  HealthCheckResult? _lastResult;
  int _consecutiveFailures = 0;
  final List<HealthCheckResult> _history = [];

  HealthCheckService({NotificationService? notifications})
      : _notifications = notifications;

  HealthCheckResult? get lastResult => _lastResult;
  List<HealthCheckResult> get history => List.unmodifiable(_history);
  bool get isRunning => _timer != null;
  int get consecutiveFailures => _consecutiveFailures;

  /// Start periodic health checks.
  void start({Duration interval = const Duration(seconds: 30)}) {
    stop();
    _log.info('Starting health checks every ${interval.inSeconds}s');
    _timer = Timer.periodic(interval, (_) => _runCheck());
    _runCheck(); // Run immediately
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Run a single health check.
  Future<HealthCheckResult> check(AgentStatus status) async {
    final stopwatch = Stopwatch()..start();
    final warnings = <String>[];

    // Check VM service
    final vmHealthy = status.vmServiceConnected;
    if (!vmHealthy) warnings.add('VM service disconnected');

    // Check MCP server
    final mcpHealthy = status.mcpServerRunning;
    if (!mcpHealthy) warnings.add('MCP server not running');

    // Check agent responsiveness (heartbeat within last 2 minutes)
    final agentResponsive = status.state != AgentState.error &&
        status.state != AgentState.stopped &&
        DateTime.now().difference(status.lastHeartbeat).inMinutes < 2;
    if (!agentResponsive) warnings.add('Agent not responsive');

    // Check for error storm (too many errors in short time)
    if (status.totalErrorsDetected > 0) {
      final recentErrors = status.recentErrors.where(
        (e) => DateTime.now().difference(e.timestamp).inMinutes < 5,
      ).length;
      if (recentErrors > 10) {
        warnings.add('Error storm detected: $recentErrors errors in 5 min');
      }
    }

    // Check success rate drop
    if (status.totalFixesApplied > 5 && status.successRate < 0.3) {
      warnings.add('Low success rate: ${(status.successRate * 100).toStringAsFixed(1)}%');
    }

    stopwatch.stop();

    final result = HealthCheckResult(
      vmServiceHealthy: vmHealthy,
      mcpServerHealthy: mcpHealthy,
      agentResponsive: agentResponsive,
      latency: stopwatch.elapsed,
      checkedAt: DateTime.now(),
      warnings: warnings,
    );

    _lastResult = result;
    _history.add(result);
    if (_history.length > 100) _history.removeAt(0);

    if (result.allHealthy) {
      _consecutiveFailures = 0;
    } else {
      _consecutiveFailures++;
      _log.warning('Health check failed ($consecutiveFailures): $warnings');

      if (_consecutiveFailures >= 3) {
        _notifications?.onHealthCheckFailed(
          'Agent unhealthy for $consecutiveFailures consecutive checks: '
          '${warnings.join(", ")}',
        );
      }
    }

    return result;
  }

  // Runs check with default empty status if no external status is provided.
  Future<void> _runCheck() async {
    // In practice, this would get the current status from the agent provider.
    _log.fine('Periodic health check tick');
  }

  void dispose() {
    stop();
  }
}

import 'dart:async';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import '../../models/agent_status.dart';
import '../../models/error_report.dart';
import '../../models/fix_record.dart';
import '../vm_service/vm_connector.dart';
import '../vm_service/error_stream.dart';
import 'error_analyzer.dart';
import 'code_fixer.dart';
import 'verification.dart';
import '../../services/ci_cd_service.dart';

/// Main self-healing agent orchestrator.
/// Coordinates error detection, analysis, fixing, verification, and PR creation.
class SelfHealingAgent {
  final VmConnector _vmConnector;
  final ErrorStream _errorStream;
  final ErrorAnalyzer _errorAnalyzer;
  final CodeFixer _codeFixer;
  final VerificationService _verificationService;
  final CiCdService _ciCdService;
  final _log = Logger('SelfHealingAgent');
  final _uuid = const Uuid();

  AgentStatus _status;
  StreamSubscription<ErrorReport>? _errorSubscription;
  final _statusController = StreamController<AgentStatus>.broadcast();
  final _fixRecordController = StreamController<FixRecord>.broadcast();
  final List<ErrorReport> _allErrors = [];
  final List<FixRecord> _allFixes = [];
  bool _autoFixEnabled = true;
  int _maxConcurrentFixes = 1;
  int _activeFixes = 0;

  SelfHealingAgent({
    required VmConnector vmConnector,
    required ErrorStream errorStream,
    required ErrorAnalyzer errorAnalyzer,
    required CodeFixer codeFixer,
    required VerificationService verificationService,
    required CiCdService ciCdService,
  })  : _vmConnector = vmConnector,
        _errorStream = errorStream,
        _errorAnalyzer = errorAnalyzer,
        _codeFixer = codeFixer,
        _verificationService = verificationService,
        _ciCdService = ciCdService,
        _status = AgentStatus(
          state: AgentState.idle,
          startedAt: DateTime.now(),
          lastHeartbeat: DateTime.now(),
        );

  AgentStatus get status => _status;
  Stream<AgentStatus> get statusStream => _statusController.stream;
  Stream<FixRecord> get fixStream => _fixRecordController.stream;
  List<ErrorReport> get allErrors => List.unmodifiable(_allErrors);
  List<FixRecord> get allFixes => List.unmodifiable(_allFixes);

  /// Start the self-healing agent loop.
  Future<void> start({String? vmServiceUri}) async {
    _log.info('Starting self-healing agent...');
    _updateStatus(state: AgentState.monitoring, currentTask: 'Connecting to VM service');

    try {
      // Connect to VM service
      if (vmServiceUri != null) {
        await _vmConnector.connect(vmServiceUri);
      } else {
        await _vmConnector.autoDiscover();
      }
      _updateStatus(vmServiceConnected: true);
      _log.info('VM service connected');

      // Start error monitoring
      final isolate = await _vmConnector.getMainIsolate();
      if (isolate != null && _vmConnector.vmService != null) {
        await _errorStream.startListening(
          _vmConnector.vmService!,
          isolate.id!,
        );
      }

      // Subscribe to error stream
      _errorSubscription = _errorStream.errorStream.listen(_onErrorDetected);
      _updateStatus(state: AgentState.monitoring, currentTask: 'Monitoring for errors');
      _log.info('Error monitoring started');

      // Start heartbeat
      _startHeartbeat();
    } catch (e, st) {
      _log.severe('Failed to start agent', e, st);
      _updateStatus(state: AgentState.error, currentTask: 'Start failed: $e');
    }
  }

  /// Stop the agent.
  Future<void> stop() async {
    _log.info('Stopping self-healing agent...');
    await _errorSubscription?.cancel();
    await _errorStream.stopListening();
    await _vmConnector.disconnect();
    _updateStatus(
      state: AgentState.stopped,
      vmServiceConnected: false,
      currentTask: null,
    );
  }

  /// Handle a detected error.
  Future<void> _onErrorDetected(ErrorReport error) async {
    _log.info('Error detected: ${error.errorType} - ${error.message}');
    _allErrors.add(error);
    _updateStatus(
      totalErrorsDetected: _status.totalErrorsDetected + 1,
      recentErrors: [..._status.recentErrors.take(19), error].toList(),
    );

    if (!_autoFixEnabled) {
      _log.info('Auto-fix disabled, skipping');
      return;
    }

    if (_activeFixes >= _maxConcurrentFixes) {
      _log.info('Max concurrent fixes reached, queuing');
      return;
    }

    await _processError(error);
  }

  /// Full self-healing pipeline for a single error.
  Future<void> _processError(ErrorReport error) async {
    _activeFixes++;
    final fixId = _uuid.v4();

    try {
      // Step 1: Analyze
      _updateStatus(state: AgentState.analyzing, currentTask: 'Analyzing: ${error.errorType}');
      _log.info('[$fixId] Analyzing error...');

      final analysis = await _errorAnalyzer.analyze(error);
      if (analysis == null || analysis.confidence < 0.5) {
        _log.warning('[$fixId] Low confidence analysis, skipping auto-fix');
        _activeFixes--;
        return;
      }

      // Step 2: Apply fix
      _updateStatus(state: AgentState.fixing, currentTask: 'Applying fix: ${analysis.suggestedFix}');
      _log.info('[$fixId] Applying fix: ${analysis.suggestedFix}');

      final fixResult = await _codeFixer.applyFix(analysis);
      if (!fixResult.success) {
        _log.severe('[$fixId] Fix application failed');
        _activeFixes--;
        return;
      }

      var fixRecord = FixRecord(
        id: fixId,
        errorReportId: error.id,
        description: analysis.suggestedFix,
        filePath: analysis.affectedFile,
        lineNumber: analysis.affectedLine,
        originalCode: fixResult.originalCode,
        fixedCode: fixResult.fixedCode,
        status: FixStatus.verifying,
        appliedAt: DateTime.now(),
      );
      _allFixes.add(fixRecord);
      _fixRecordController.add(fixRecord);

      // Step 3: Verify
      _updateStatus(state: AgentState.verifying, currentTask: 'Verifying fix...');
      _log.info('[$fixId] Verifying fix...');

      final verification = await _verificationService.verifyFix(
        analysis.affectedFile,
        fixResult.backupPath,
      );

      fixRecord = fixRecord.copyWith(
        analysisPassed: verification.analysisPassed,
        status: verification.isVerified ? FixStatus.verified : FixStatus.failed,
        verifiedAt: DateTime.now(),
        failureReason: verification.isVerified ? null : verification.errors.join('; '),
      );
      _updateFixRecord(fixRecord);

      if (!verification.isVerified) {
        _log.warning('[$fixId] Verification failed, rollback performed: ${verification.rollbackPerformed}');
        _updateStatus(
          totalFixesApplied: _status.totalFixesApplied + 1,
        );
        _activeFixes--;
        return;
      }

      // Step 4: Create PR
      _updateStatus(state: AgentState.creatingPR, currentTask: 'Creating pull request...');
      _log.info('[$fixId] Creating PR...');

      final prUrl = await _ciCdService.createPullRequest(fixRecord);
      fixRecord = fixRecord.copyWith(
        status: FixStatus.prCreated,
        prUrl: prUrl,
      );
      _updateFixRecord(fixRecord);

      _updateStatus(
        state: AgentState.monitoring,
        totalFixesApplied: _status.totalFixesApplied + 1,
        totalFixesVerified: _status.totalFixesVerified + 1,
        totalPRsCreated: _status.totalPRsCreated + 1,
        currentTask: 'Monitoring for errors',
      );

      _log.info('[$fixId] Self-healing complete! PR: $prUrl');
    } catch (e, st) {
      _log.severe('[$fixId] Self-healing pipeline failed', e, st);
      _updateStatus(state: AgentState.monitoring, currentTask: 'Monitoring for errors');
    } finally {
      _activeFixes--;
      _recalculateSuccessRate();
    }
  }

  void _updateFixRecord(FixRecord record) {
    final index = _allFixes.indexWhere((f) => f.id == record.id);
    if (index >= 0) {
      _allFixes[index] = record;
    }
    _fixRecordController.add(record);
    _updateStatus(
      recentFixes: [..._status.recentFixes.take(19), record].toList(),
    );
  }

  void _recalculateSuccessRate() {
    if (_allFixes.isEmpty) return;
    final verified = _allFixes.where((f) => f.status == FixStatus.verified || f.status == FixStatus.prCreated || f.status == FixStatus.merged).length;
    _updateStatus(successRate: verified / _allFixes.length);
  }

  void _updateStatus({
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
  }) {
    _status = _status.copyWith(
      state: state,
      lastHeartbeat: lastHeartbeat ?? DateTime.now(),
      totalErrorsDetected: totalErrorsDetected,
      totalFixesApplied: totalFixesApplied,
      totalFixesVerified: totalFixesVerified,
      totalPRsCreated: totalPRsCreated,
      recentErrors: recentErrors,
      recentFixes: recentFixes,
      currentTask: currentTask,
      successRate: successRate,
      vmServiceConnected: vmServiceConnected,
      mcpServerRunning: mcpServerRunning,
    );
    _statusController.add(_status);
  }

  void _startHeartbeat() {
    Timer.periodic(const Duration(seconds: 30), (_) {
      if (_status.state != AgentState.stopped) {
        _updateStatus(lastHeartbeat: DateTime.now());
      }
    });
  }

  void setAutoFix(bool enabled) {
    _autoFixEnabled = enabled;
    _log.info('Auto-fix ${enabled ? "enabled" : "disabled"}');
  }

  void setMaxConcurrentFixes(int max) {
    _maxConcurrentFixes = max;
  }

  Future<void> dispose() async {
    await stop();
    await _statusController.close();
    await _fixRecordController.close();
  }
}

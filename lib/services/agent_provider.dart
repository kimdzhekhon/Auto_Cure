import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/agent_status.dart';
import '../models/error_report.dart';
import '../models/fix_record.dart';
import '../core/self_healing/agent.dart';
import '../core/vm_service/vm_connector.dart';
import '../core/vm_service/error_stream.dart';
import '../core/self_healing/error_analyzer.dart';
import '../core/self_healing/code_fixer.dart';
import '../core/self_healing/verification.dart';
import 'ci_cd_service.dart';

/// Provider for the self-healing agent, bridges the agent to Flutter UI.
class AgentProvider extends ChangeNotifier {
  late final SelfHealingAgent _agent;
  AgentStatus _status = AgentStatus(
    state: AgentState.idle,
    startedAt: DateTime.now(),
    lastHeartbeat: DateTime.now(),
  );
  final List<ErrorReport> _errors = [];
  final List<FixRecord> _fixes = [];
  StreamSubscription<AgentStatus>? _statusSub;
  StreamSubscription<FixRecord>? _fixSub;
  final String _projectRoot;
  bool _initialized = false;

  AgentProvider({required String projectRoot}) : _projectRoot = projectRoot;

  AgentStatus get status => _status;
  List<ErrorReport> get errors => List.unmodifiable(_errors);
  List<FixRecord> get fixes => List.unmodifiable(_fixes);
  bool get isRunning => _status.state == AgentState.monitoring;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    final vmConnector = VmConnector();
    final errorStream = ErrorStream();
    final analyzer = ErrorAnalyzer(projectRoot: _projectRoot);
    final fixer = CodeFixer(projectRoot: _projectRoot);
    final verification = VerificationService(projectRoot: _projectRoot);
    final ciCd = CiCdService(projectRoot: _projectRoot);

    _agent = SelfHealingAgent(
      vmConnector: vmConnector,
      errorStream: errorStream,
      errorAnalyzer: analyzer,
      codeFixer: fixer,
      verificationService: verification,
      ciCdService: ciCd,
    );

    _statusSub = _agent.statusStream.listen((s) {
      _status = s;
      _errors
        ..clear()
        ..addAll(_agent.allErrors);
      notifyListeners();
    });

    _fixSub = _agent.fixStream.listen((fix) {
      final idx = _fixes.indexWhere((f) => f.id == fix.id);
      if (idx >= 0) {
        _fixes[idx] = fix;
      } else {
        _fixes.add(fix);
      }
      notifyListeners();
    });

    _initialized = true;
    notifyListeners();
  }

  Future<void> startAgent({String? vmServiceUri}) async {
    await _agent.start(vmServiceUri: vmServiceUri);
  }

  Future<void> stopAgent() async {
    await _agent.stop();
  }

  void toggleAutoFix(bool enabled) {
    _agent.setAutoFix(enabled);
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _fixSub?.cancel();
    _agent.dispose();
    super.dispose();
  }
}

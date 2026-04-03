import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Connects to Flutter's VM service over WebSocket and provides
/// convenience helpers for isolate inspection, expression evaluation,
/// and stack-trace retrieval.
class VmConnector {
  VmConnector({Duration? reconnectDelay})
      : _reconnectDelay = reconnectDelay ?? const Duration(seconds: 3);

  static final Logger _log = Logger('VmConnector');

  final Duration _reconnectDelay;

  VmService? _vmService;
  WebSocketChannel? _channel;
  String? _connectedUri;
  bool _shouldReconnect = false;
  Timer? _reconnectTimer;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Whether a live VM service connection is currently open.
  bool get isConnected => _vmService != null;

  /// The raw [VmService] client for advanced usage.
  ///
  /// Throws [StateError] if not connected.
  VmService get vmService {
    if (_vmService == null) {
      throw StateError('Not connected to a VM service. Call connect() first.');
    }
    return _vmService!;
  }

  /// The URI that was used for the current (or last) connection.
  String? get connectedUri => _connectedUri;

  /// Connect to the Flutter VM service at [uri].
  ///
  /// The [uri] should be a WebSocket URI such as
  /// `ws://127.0.0.1:12345/AbCdEf=/ws`.
  ///
  /// Set [autoReconnect] to `true` to automatically attempt reconnection when
  /// the connection drops.
  Future<void> connect(String uri, {bool autoReconnect = false}) async {
    _shouldReconnect = autoReconnect;
    await _establishConnection(uri);
  }

  /// Auto-discover the VM service URI by scanning the Flutter device log
  /// output on the local machine.
  ///
  /// This runs `flutter logs` (or checks the process stdout) and looks for the
  /// well-known observatory / VM service URI pattern. Returns the discovered
  /// URI or throws if none is found within [timeout].
  Future<String> autoDiscover({Duration? timeout}) async {
    final effectiveTimeout = timeout ?? const Duration(seconds: 30);
    _log.info('Auto-discovering VM service URI (timeout: $effectiveTimeout)...');

    final completer = Completer<String>();

    final process = await Process.start(
      'flutter',
      ['logs', '--machine'],
      runInShell: true,
    );

    final uriPattern = RegExp(
      r'(wss?://127\.0\.0\.1:\d+/[^\s"]+/ws)',
    );

    late final StreamSubscription<List<int>> stdoutSub;
    late final StreamSubscription<List<int>> stderrSub;

    void tryMatch(String line) {
      final match = uriPattern.firstMatch(line);
      if (match != null && !completer.isCompleted) {
        final uri = match.group(1)!;
        _log.info('Discovered VM service URI: $uri');
        completer.complete(uri);
      }
    }

    stdoutSub = process.stdout
        .transform(const SystemEncoding().decoder)
        .listen((data) {
      for (final line in data.split('\n')) {
        tryMatch(line);
      }
    });

    stderrSub = process.stderr
        .transform(const SystemEncoding().decoder)
        .listen((data) {
      for (final line in data.split('\n')) {
        tryMatch(line);
      }
    });

    try {
      final uri = await completer.future.timeout(effectiveTimeout);
      return uri;
    } on TimeoutException {
      _log.warning('Auto-discovery timed out after $effectiveTimeout.');
      rethrow;
    } finally {
      await stdoutSub.cancel();
      await stderrSub.cancel();
      process.kill();
    }
  }

  /// Disconnect from the VM service and cancel any pending reconnect timers.
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _teardown();
    _log.info('Disconnected from VM service.');
  }

  /// Returns the [IsolateRef] of the main isolate for the connected VM.
  ///
  /// Throws if no isolate is found or if not connected.
  Future<IsolateRef> getMainIsolate() async {
    final vm = await vmService.getVM();
    final isolates = vm.isolates;
    if (isolates == null || isolates.isEmpty) {
      throw StateError('No isolates found in the connected VM.');
    }

    // Prefer the isolate named "main" if present; otherwise return the first.
    return isolates.firstWhere(
      (i) => i.name == 'main',
      orElse: () => isolates.first,
    );
  }

  /// Evaluate a Dart [expression] in the context of [isolateId] and
  /// optionally within a specific [targetId] (library, class, or frame).
  ///
  /// Returns the [InstanceRef] of the evaluation result.
  Future<Response> evaluate(
    String isolateId,
    String targetId,
    String expression,
  ) async {
    _log.fine('Evaluating expression in isolate $isolateId: $expression');
    return vmService.evaluate(isolateId, targetId, expression);
  }

  /// Retrieve the current stack trace for [isolateId].
  Future<Stack> getStackTrace(String isolateId) async {
    _log.fine('Retrieving stack trace for isolate $isolateId');
    return vmService.getStack(isolateId);
  }

  /// Retrieve detailed [Isolate] information for [isolateId].
  Future<Isolate> getIsolateInfo(String isolateId) async {
    return vmService.getIsolate(isolateId);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _establishConnection(String uri) async {
    await _teardown();

    _connectedUri = uri;
    _log.info('Connecting to VM service at $uri ...');

    try {
      _vmService = await vmServiceConnectUri(uri);
      _log.info('Connected to VM service at $uri');

      // Listen for the service closing so we can reconnect if needed.
      _vmService!.onDone.then((_) => _onConnectionLost());
    } catch (e, st) {
      _log.severe('Failed to connect to VM service at $uri', e, st);
      _vmService = null;
      _scheduleReconnect();
      rethrow;
    }
  }

  void _onConnectionLost() {
    _log.warning('VM service connection lost.');
    _vmService = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect || _connectedUri == null) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () async {
      _log.info('Attempting to reconnect to $_connectedUri ...');
      try {
        await _establishConnection(_connectedUri!);
      } catch (_) {
        // _establishConnection already logs and schedules the next retry.
      }
    });
  }

  Future<void> _teardown() async {
    try {
      await _vmService?.dispose();
    } catch (_) {
      // Best-effort cleanup.
    }
    try {
      await _channel?.sink.close();
    } catch (_) {
      // Best-effort cleanup.
    }
    _vmService = null;
    _channel = null;
  }
}

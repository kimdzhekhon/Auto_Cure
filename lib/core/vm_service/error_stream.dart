import 'dart:async';

import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import 'package:vm_service/vm_service.dart';

import 'package:autocure/models/error_report.dart';

/// Categorises the Flutter errors that [ErrorStream] can recognise.
enum FlutterErrorType {
  renderFlexOverflow,
  renderBoxNotLaidOut,
  nullCheckOperator,
  setStateAfterDispose,
  typeError,
  unknown,
}

/// Listens to Flutter's VM service extension events and stderr output for
/// runtime errors, parses them into [ErrorReport] objects, and exposes them
/// through a broadcast [Stream].
class ErrorStream {
  ErrorStream();

  static final Logger _log = Logger('ErrorStream');
  static const Uuid _uuid = Uuid();

  // ---------------------------------------------------------------------------
  // Error patterns
  // ---------------------------------------------------------------------------

  static final Map<FlutterErrorType, RegExp> _errorPatterns = {
    FlutterErrorType.renderFlexOverflow: RegExp(
      r'A RenderFlex overflowed by ([\d.]+) pixels on the (right|left|top|bottom)',
    ),
    FlutterErrorType.renderBoxNotLaidOut: RegExp(
      r'RenderBox was not laid out',
    ),
    FlutterErrorType.nullCheckOperator: RegExp(
      r'Null check operator used on a null value',
    ),
    FlutterErrorType.setStateAfterDispose: RegExp(
      r"setState\(\) called after dispose\(\)",
    ),
    FlutterErrorType.typeError: RegExp(
      r"type '([^']+)' is not a subtype of type '([^']+)'",
    ),
  };

  // Extracts a file location like `package:foo/bar.dart:42:10`.
  static final RegExp _fileLocationPattern = RegExp(
    r'(package:[^\s]+\.dart:\d+:\d+)',
  );

  // Extracts a widget path from the "The relevant error-causing widget was"
  // diagnostic line.
  static final RegExp _widgetPathPattern = RegExp(
    r'The relevant error-causing widget was:\s*\n?\s*(\S+)',
  );

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  final StreamController<ErrorReport> _controller =
      StreamController<ErrorReport>.broadcast();

  final List<ErrorReport> _capturedErrors = [];

  StreamSubscription<Event>? _stderrSub;
  StreamSubscription<Event>? _extensionSub;
  StreamSubscription<Event>? _debugSub;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// A broadcast stream of [ErrorReport] objects emitted whenever a recognised
  /// Flutter error is captured.
  Stream<ErrorReport> get errorStream => _controller.stream;

  /// All [ErrorReport]s captured since the last [startListening] call (or
  /// since construction if never stopped).
  List<ErrorReport> get capturedErrors => List.unmodifiable(_capturedErrors);

  /// Begin listening for errors on the given [vmService] and [isolateId].
  ///
  /// Subscribes to:
  /// - `Stderr` events (for RenderFlex overflow messages printed to stderr)
  /// - `Extension` events (for structured Flutter.Error events)
  Future<void> startListening(
    VmService vmService,
    String isolateId,
  ) async {
    _log.info('Starting error stream for isolate $isolateId');

    // Ensure we are subscribed to the relevant event streams.
    await _safeStreamListen(vmService, EventStreams.kStderr);
    await _safeStreamListen(vmService, EventStreams.kExtension);
    await _safeStreamListen(vmService, EventStreams.kDebug);

    // Stderr events --------------------------------------------------------
    _stderrSub = vmService.onStderrEvent.listen((event) {
      final bytes = event.bytes;
      if (bytes == null) return;
      final message = String.fromCharCodes(bytes.codeUnits);
      _processRawMessage(message);
    });

    // Extension events (Flutter.Error) -------------------------------------
    _extensionSub = vmService.onExtensionEvent.listen((event) {
      if (event.extensionKind == 'Flutter.Error') {
        _processExtensionError(event);
      }
    });

    // Debug events (uncaught exceptions) -----------------------------------
    _debugSub = vmService.onDebugEvent.listen((event) {
      if (event.kind == EventKind.kPauseException) {
        _processDebugException(event, isolateId);
      }
    });

    _log.info('Error stream listening.');
  }

  /// Stop listening and clean up subscriptions.
  ///
  /// Captured errors are retained and accessible via [capturedErrors] until a
  /// new [startListening] call resets them.
  Future<void> stopListening() async {
    _log.info('Stopping error stream.');

    await _stderrSub?.cancel();
    await _extensionSub?.cancel();
    await _debugSub?.cancel();

    _stderrSub = null;
    _extensionSub = null;
    _debugSub = null;
  }

  /// Release all resources. After calling [dispose] this instance must not be
  /// reused.
  Future<void> dispose() async {
    await stopListening();
    await _controller.close();
  }

  // ---------------------------------------------------------------------------
  // Internal: event processing
  // ---------------------------------------------------------------------------

  void _processRawMessage(String message) {
    final errorType = _classifyError(message);
    if (errorType == null) return;

    final report = _buildReport(
      errorType: errorType,
      rawMessage: message,
    );

    _emit(report);
  }

  void _processExtensionError(Event event) {
    final data = event.extensionData?.data;
    if (data == null) return;

    final description = data['description']?.toString() ?? '';
    final errorType = _classifyError(description) ?? FlutterErrorType.unknown;

    final report = _buildReport(
      errorType: errorType,
      rawMessage: description,
      extensionData: data,
    );

    _emit(report);
  }

  void _processDebugException(Event event, String isolateId) {
    final exception = event.exception;
    if (exception == null) return;

    final valueStr = exception.valueAsString ?? exception.kind ?? 'Unknown';
    final errorType = _classifyError(valueStr) ?? FlutterErrorType.unknown;

    final report = _buildReport(
      errorType: errorType,
      rawMessage: valueStr,
    );

    _emit(report);
  }

  // ---------------------------------------------------------------------------
  // Internal: helpers
  // ---------------------------------------------------------------------------

  FlutterErrorType? _classifyError(String message) {
    for (final entry in _errorPatterns.entries) {
      if (entry.value.hasMatch(message)) {
        return entry.key;
      }
    }
    return null;
  }

  ErrorReport _buildReport({
    required FlutterErrorType errorType,
    required String rawMessage,
    Map<String, dynamic>? extensionData,
  }) {
    // Attempt to extract file location.
    final fileMatch = _fileLocationPattern.firstMatch(rawMessage);
    final fileLocation = fileMatch?.group(1);

    // Attempt to extract widget path.
    final widgetMatch = _widgetPathPattern.firstMatch(rawMessage);
    final widgetPath = widgetMatch?.group(1);

    // Extract a stack trace block if present. The convention in Flutter error
    // output is to indent stack frames with `#N  ...` lines.
    final stackTrace = _extractStackTrace(rawMessage);

    return ErrorReport(
      id: _uuid.v4(),
      errorType: errorType.name,
      message: _summarise(rawMessage, errorType),
      rawMessage: rawMessage,
      widgetPath: widgetPath,
      fileLocation: fileLocation,
      stackTrace: stackTrace ?? '',
      timestamp: DateTime.now(),
      extensionData: extensionData,
    );
  }

  /// Produce a short human-readable summary for the error.
  String _summarise(String raw, FlutterErrorType type) {
    switch (type) {
      case FlutterErrorType.renderFlexOverflow:
        final m = _errorPatterns[type]!.firstMatch(raw);
        if (m != null) {
          return 'RenderFlex overflowed by ${m.group(1)} pixels on the ${m.group(2)}';
        }
        return 'RenderFlex overflow';
      case FlutterErrorType.renderBoxNotLaidOut:
        return 'RenderBox was not laid out';
      case FlutterErrorType.nullCheckOperator:
        return 'Null check operator used on a null value';
      case FlutterErrorType.setStateAfterDispose:
        return 'setState() called after dispose()';
      case FlutterErrorType.typeError:
        final m = _errorPatterns[type]!.firstMatch(raw);
        if (m != null) {
          return "Type error: '${m.group(1)}' is not a subtype of '${m.group(2)}'";
        }
        return 'Type error';
      case FlutterErrorType.unknown:
        // Return the first non-empty line, truncated.
        final firstLine = raw.split('\n').firstWhere(
              (l) => l.trim().isNotEmpty,
              orElse: () => 'Unknown error',
            );
        return firstLine.length > 120
            ? '${firstLine.substring(0, 117)}...'
            : firstLine;
    }
  }

  String? _extractStackTrace(String message) {
    final framePattern = RegExp(r'^#\d+\s+.+$', multiLine: true);
    final matches = framePattern.allMatches(message);
    if (matches.isEmpty) return null;
    return matches.map((m) => m.group(0)).join('\n');
  }

  void _emit(ErrorReport report) {
    _capturedErrors.add(report);
    _controller.add(report);
    _log.info(
      'Captured ${report.errorType}: ${report.message}',
    );
  }

  Future<void> _safeStreamListen(VmService vmService, String streamId) async {
    try {
      await vmService.streamListen(streamId);
    } catch (e) {
      // Already subscribed — this is fine.
      _log.fine('Stream $streamId already subscribed: $e');
    }
  }
}

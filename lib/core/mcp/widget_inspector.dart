import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';


/// A service that connects to Flutter's VM service protocol via WebSocket
/// to inspect widgets, retrieve the widget tree, and detect layout issues.
class WidgetInspector {
  WidgetInspector();

  final Logger _log = Logger('WidgetInspector');

  WebSocket? _socket;
  String? _isolateId;
  int _requestId = 0;
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};
  StreamSubscription<dynamic>? _subscription;

  /// Whether the inspector is currently connected to a VM service.
  bool get isConnected => _socket != null;

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  /// Connects to the Flutter VM service at [vmServiceUri].
  ///
  /// The URI should be a WebSocket address, e.g. `ws://127.0.0.1:XXXXX/ws`.
  Future<void> connect(String vmServiceUri) async {
    _log.info('Connecting to VM service at $vmServiceUri');

    _socket = await WebSocket.connect(vmServiceUri);

    _subscription = _socket!.listen(
      _onMessage,
      onError: (Object error) {
        _log.severe('WebSocket error: $error');
      },
      onDone: () {
        _log.info('WebSocket connection closed');
        _cleanup();
      },
    );

    // Discover the main isolate.
    final vmInfo = await _send('getVM');
    final isolates = vmInfo['isolates'] as List<dynamic>? ?? [];
    if (isolates.isEmpty) {
      throw StateError('No isolates found in the Flutter VM');
    }

    _isolateId =
        (isolates.first as Map<String, dynamic>)['id'] as String;
    _log.info('Connected — using isolate $_isolateId');
  }

  /// Gracefully disconnects from the VM service.
  Future<void> disconnect() async {
    await _socket?.close();
    _cleanup();
    _log.info('Disconnected from VM service');
  }

  // ---------------------------------------------------------------------------
  // Widget tree
  // ---------------------------------------------------------------------------

  /// Retrieves the full widget tree as a structured [Map].
  ///
  /// The returned map mirrors the hierarchy produced by the Flutter inspector
  /// protocol with keys such as `description`, `children`, `creationLocation`,
  /// etc.
  Future<Map<String, dynamic>> getWidgetTree() async {
    _ensureConnected();

    final result = await _send(
      'ext.flutter.inspector.getRootWidgetSummaryTree',
      params: {
        'isolateId': _isolateId!,
        'groupName': _nextGroup(),
      },
    );

    return _normalizeTreeNode(result);
  }

  // ---------------------------------------------------------------------------
  // Widget details
  // ---------------------------------------------------------------------------

  /// Returns details about a specific widget identified by [widgetId].
  ///
  /// The result includes type, properties, constraints, and render size when
  /// available.
  Future<Map<String, dynamic>> getWidgetDetails(String widgetId) async {
    _ensureConnected();

    final result = await _send(
      'ext.flutter.inspector.getDetailsSubtree',
      params: {
        'isolateId': _isolateId!,
        'arg': widgetId,
        'subtreeDepth': 2,
        'groupName': _nextGroup(),
      },
    );

    final properties =
        (result['properties'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];

    final renderObject =
        result['renderObject'] as Map<String, dynamic>?;

    return {
      'widget_id': widgetId,
      'type': result['description'] ?? result['widgetRuntimeType'],
      'properties': properties.map((p) {
        return {
          'name': p['name'],
          'value': p['description'] ?? p['value'],
          'type': p['propertyType'],
        };
      }).toList(),
      'constraints': _extractConstraints(renderObject),
      'size': _extractSize(renderObject),
      'creation_location': result['creationLocation'],
    };
  }

  // ---------------------------------------------------------------------------
  // Source location
  // ---------------------------------------------------------------------------

  /// Finds the source file and line number where the widget identified by
  /// [widgetId] is constructed.
  Future<Map<String, dynamic>> findWidgetSource(String widgetId) async {
    _ensureConnected();

    final result = await _send(
      'ext.flutter.inspector.getDetailsSubtree',
      params: {
        'isolateId': _isolateId!,
        'arg': widgetId,
        'subtreeDepth': 0,
        'groupName': _nextGroup(),
      },
    );

    final location =
        result['creationLocation'] as Map<String, dynamic>?;

    if (location == null) {
      return {
        'widget_id': widgetId,
        'found': false,
        'message': 'Creation location not available for this widget.',
      };
    }

    return {
      'widget_id': widgetId,
      'found': true,
      'file': location['file'],
      'line': location['line'],
      'column': location['column'],
    };
  }

  // ---------------------------------------------------------------------------
  // Layout issue detection
  // ---------------------------------------------------------------------------

  /// Walks the render tree and detects common layout issues such as
  /// overflow errors and unbounded constraints.
  ///
  /// Returns a list of maps, each describing one detected issue.
  Future<List<Map<String, dynamic>>> detectLayoutIssues() async {
    _ensureConnected();

    final issues = <Map<String, dynamic>>[];

    // 1. Check for render flex overflow via the Flutter error service.
    final errorResult = await _send(
      'ext.flutter.inspector.structuredErrors',
      params: {'isolateId': _isolateId!},
    );

    final errors =
        (errorResult['errors'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];

    for (final error in errors) {
      final description = error['description'] as String? ?? '';
      if (description.contains('overflowed') ||
          description.contains('OVERFLOW')) {
        issues.add({
          'type': 'overflow',
          'description': description,
          'widget_id': error['widgetId'],
          'creation_location': error['creationLocation'],
        });
      }
    }

    // 2. Walk the render tree to find unbounded constraints.
    final tree = await _send(
      'ext.flutter.inspector.getRootRenderObject',
      params: {
        'isolateId': _isolateId!,
        'groupName': _nextGroup(),
      },
    );

    _findUnboundedConstraints(tree, issues);

    _log.info('Detected ${issues.length} layout issue(s)');
    return issues;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _ensureConnected() {
    if (_socket == null || _isolateId == null) {
      throw StateError(
        'Not connected to a VM service. Call connect() first.',
      );
    }
  }

  String _nextGroup() => 'autocure_inspector_${_requestId + 1}';

  /// Sends a JSON-RPC request over the WebSocket and waits for the response.
  Future<Map<String, dynamic>> _send(
    String method, {
    Map<String, dynamic>? params,
  }) async {
    _ensureConnected();

    _requestId++;
    final id = _requestId.toString();

    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;

    final request = <String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
    };
    if (params != null) {
      request['params'] = params;
    }

    _socket!.add(jsonEncode(request));

    // Time out after 15 seconds to avoid hanging indefinitely.
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _pendingRequests.remove(id);
        throw TimeoutException('Request $method (id=$id) timed out');
      },
    );
  }

  /// Handles incoming WebSocket messages and completes pending requests.
  void _onMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final id = message['id'] as String?;
      if (id != null && _pendingRequests.containsKey(id)) {
        final completer = _pendingRequests.remove(id)!;
        if (message.containsKey('error')) {
          completer.completeError(
            Exception(jsonEncode(message['error'])),
          );
        } else {
          completer.complete(
            message['result'] as Map<String, dynamic>? ?? {},
          );
        }
      }
    } catch (e) {
      _log.warning('Failed to process incoming message: $e');
    }
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _socket = null;
    _isolateId = null;

    // Fail any outstanding requests.
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Connection closed before response received'),
        );
      }
    }
    _pendingRequests.clear();
  }

  /// Normalises a widget tree node returned by the inspector protocol into a
  /// consistent structure.
  Map<String, dynamic> _normalizeTreeNode(Map<String, dynamic> node) {
    final children = (node['children'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .map(_normalizeTreeNode)
            .toList() ??
        [];

    return {
      'widget_id': node['valueId'] ?? node['objectId'],
      'type': node['description'] ?? node['widgetRuntimeType'],
      'creation_location': node['creationLocation'],
      'children': children,
    };
  }

  /// Extracts box constraints from a render object map.
  Map<String, dynamic>? _extractConstraints(
    Map<String, dynamic>? renderObject,
  ) {
    if (renderObject == null) return null;

    final properties =
        (renderObject['properties'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];

    for (final prop in properties) {
      if (prop['name'] == 'constraints') {
        return {
          'description': prop['description'],
          'value': prop['value'],
        };
      }
    }
    return null;
  }

  /// Extracts size information from a render object map.
  Map<String, dynamic>? _extractSize(Map<String, dynamic>? renderObject) {
    if (renderObject == null) return null;

    final properties =
        (renderObject['properties'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];

    for (final prop in properties) {
      if (prop['name'] == 'size') {
        return {
          'description': prop['description'],
          'value': prop['value'],
        };
      }
    }
    return null;
  }

  /// Recursively inspects the render tree for nodes with unbounded (infinite)
  /// constraints and appends them to [issues].
  void _findUnboundedConstraints(
    Map<String, dynamic> node,
    List<Map<String, dynamic>> issues,
  ) {
    final properties =
        (node['properties'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];

    for (final prop in properties) {
      if (prop['name'] == 'constraints') {
        final desc = (prop['description'] as String?) ?? '';
        if (desc.contains('Infinity') || desc.contains('unbounded')) {
          issues.add({
            'type': 'unbounded_constraints',
            'description':
                'Widget has unbounded constraints: $desc',
            'widget_id': node['valueId'] ?? node['objectId'],
            'widget_type': node['description'],
            'creation_location': node['creationLocation'],
          });
        }
      }
    }

    final children =
        (node['children'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];
    for (final child in children) {
      _findUnboundedConstraints(child, issues);
    }
  }
}

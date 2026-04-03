import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

/// A JSON-RPC based MCP (Model Context Protocol) server that exposes
/// Flutter project inspection and modification tools over stdin/stdout.
class McpServer {
  McpServer({
    required this.projectRoot,
  });

  final String projectRoot;
  final Logger _log = Logger('McpServer');

  bool _initialized = false;

  static const String _serverName = 'autocure-mcp-server';
  static const String _serverVersion = '1.0.0';
  static const String _protocolVersion = '2024-11-05';

  /// Starts the MCP server, listening on stdin and writing responses to stdout.
  Future<void> start() async {
    _log.info('Starting MCP server with project root: $projectRoot');

    final inputStream = stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in inputStream) {
      if (line.trim().isEmpty) continue;

      try {
        final request = jsonDecode(line) as Map<String, dynamic>;
        final response = await _handleRequest(request);
        if (response != null) {
          _sendResponse(response);
        }
      } catch (e, st) {
        _log.severe('Error handling request: $e', e, st);
        _sendResponse(_errorResponse(
          id: null,
          code: -32700,
          message: 'Parse error: $e',
        ));
      }
    }
  }

  /// Dispatches an incoming JSON-RPC request to the appropriate handler.
  Future<Map<String, dynamic>?> _handleRequest(
    Map<String, dynamic> request,
  ) async {
    final method = request['method'] as String?;
    final id = request['id'];
    final params = request['params'] as Map<String, dynamic>? ?? {};

    _log.fine('Received method: $method');

    switch (method) {
      case 'initialize':
        return _handleInitialize(id, params);
      case 'initialized':
        // Notification — no response required.
        return null;
      case 'tools/list':
        return _handleToolsList(id);
      case 'tools/call':
        return _handleToolsCall(id, params);
      case 'ping':
        return _successResponse(id: id, result: {});
      default:
        return _errorResponse(
          id: id,
          code: -32601,
          message: 'Method not found: $method',
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Protocol handlers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _handleInitialize(
    dynamic id,
    Map<String, dynamic> params,
  ) {
    _initialized = true;
    _log.info('MCP session initialized');

    return _successResponse(
      id: id,
      result: {
        'protocolVersion': _protocolVersion,
        'capabilities': {
          'tools': {'listChanged': false},
        },
        'serverInfo': {
          'name': _serverName,
          'version': _serverVersion,
        },
      },
    );
  }

  Map<String, dynamic> _handleToolsList(dynamic id) {
    return _successResponse(
      id: id,
      result: {
        'tools': [
          {
            'name': 'get_widget_tree',
            'description':
                'Retrieves the current Flutter widget tree structure by '
                    'connecting to the Flutter VM service.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'vm_service_uri': {
                  'type': 'string',
                  'description':
                      'The URI of the Flutter VM service (e.g. '
                          'ws://127.0.0.1:XXXXX/ws).',
                },
              },
              'required': ['vm_service_uri'],
            },
          },
          {
            'name': 'get_source_code',
            'description':
                'Reads a Dart source file and returns its contents with '
                    'line numbers.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'file_path': {
                  'type': 'string',
                  'description':
                      'Absolute or project-relative path to the Dart file.',
                },
              },
              'required': ['file_path'],
            },
          },
          {
            'name': 'analyze_file',
            'description':
                'Runs `dart analyze` on a specific file and returns '
                    'diagnostics.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'file_path': {
                  'type': 'string',
                  'description': 'Path to the Dart file to analyze.',
                },
              },
              'required': ['file_path'],
            },
          },
          {
            'name': 'apply_fix',
            'description':
                'Applies a code fix by replacing a section of code in a '
                    'file at a given line.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'file_path': {
                  'type': 'string',
                  'description': 'Path to the Dart file to modify.',
                },
                'line_number': {
                  'type': 'integer',
                  'description':
                      'The 1-based line number where the replacement starts.',
                },
                'original_code': {
                  'type': 'string',
                  'description': 'The original code snippet to find.',
                },
                'replacement_code': {
                  'type': 'string',
                  'description': 'The replacement code snippet.',
                },
              },
              'required': [
                'file_path',
                'line_number',
                'original_code',
                'replacement_code',
              ],
            },
          },
        ],
      },
    );
  }

  Future<Map<String, dynamic>> _handleToolsCall(
    dynamic id,
    Map<String, dynamic> params,
  ) async {
    if (!_initialized) {
      return _errorResponse(
        id: id,
        code: -32002,
        message: 'Server not initialized',
      );
    }

    final toolName = params['name'] as String?;
    final arguments =
        params['arguments'] as Map<String, dynamic>? ?? {};

    try {
      final result = await _dispatchTool(toolName, arguments);
      return _successResponse(
        id: id,
        result: {
          'content': [
            {'type': 'text', 'text': jsonEncode(result)},
          ],
        },
      );
    } catch (e, st) {
      _log.warning('Tool "$toolName" failed: $e', e, st);
      return _successResponse(
        id: id,
        result: {
          'content': [
            {'type': 'text', 'text': 'Error: $e'},
          ],
          'isError': true,
        },
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Tool implementations
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _dispatchTool(
    String? toolName,
    Map<String, dynamic> arguments,
  ) async {
    switch (toolName) {
      case 'get_widget_tree':
        return _toolGetWidgetTree(arguments);
      case 'get_source_code':
        return _toolGetSourceCode(arguments);
      case 'analyze_file':
        return _toolAnalyzeFile(arguments);
      case 'apply_fix':
        return _toolApplyFix(arguments);
      default:
        throw ArgumentError('Unknown tool: $toolName');
    }
  }

  /// Connects to the Flutter VM service and retrieves the widget tree.
  Future<Map<String, dynamic>> _toolGetWidgetTree(
    Map<String, dynamic> arguments,
  ) async {
    final vmServiceUri = arguments['vm_service_uri'] as String?;
    if (vmServiceUri == null || vmServiceUri.isEmpty) {
      throw ArgumentError('vm_service_uri is required');
    }

    WebSocket? socket;
    try {
      socket = await WebSocket.connect(vmServiceUri);

      // Request the list of VM isolates.
      final getVmRequest = jsonEncode({
        'jsonrpc': '2.0',
        'id': '1',
        'method': 'getVM',
      });
      socket.add(getVmRequest);

      final vmResponseRaw = await socket.first;
      final vmResponse =
          jsonDecode(vmResponseRaw as String) as Map<String, dynamic>;
      final vmResult = vmResponse['result'] as Map<String, dynamic>?;

      final isolates = vmResult?['isolates'] as List<dynamic>? ?? [];
      if (isolates.isEmpty) {
        return {'widget_tree': null, 'message': 'No isolates found'};
      }

      final isolateId =
          (isolates.first as Map<String, dynamic>)['id'] as String;

      // Call the Flutter extension to get the render tree summary.
      final getRenderTreeRequest = jsonEncode({
        'jsonrpc': '2.0',
        'id': '2',
        'method': 'ext.flutter.inspector.getRootWidgetSummaryTree',
        'params': {'isolateId': isolateId},
      });
      socket.add(getRenderTreeRequest);

      final treeResponseRaw = await socket
          .firstWhere((event) {
            final decoded =
                jsonDecode(event as String) as Map<String, dynamic>;
            return decoded['id'] == '2';
          });
      final treeResponse =
          jsonDecode(treeResponseRaw as String) as Map<String, dynamic>;

      return {
        'widget_tree': treeResponse['result'],
        'isolate_id': isolateId,
      };
    } finally {
      await socket?.close();
    }
  }

  /// Reads a Dart source file and returns its contents with line numbers.
  Future<Map<String, dynamic>> _toolGetSourceCode(
    Map<String, dynamic> arguments,
  ) async {
    final filePath = _resolvePath(arguments['file_path'] as String?);
    final file = File(filePath);

    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final lines = await file.readAsLines();
    final numberedLines = <String>[];
    for (var i = 0; i < lines.length; i++) {
      numberedLines.add('${(i + 1).toString().padLeft(5)}: ${lines[i]}');
    }

    return {
      'file_path': filePath,
      'line_count': lines.length,
      'content': numberedLines.join('\n'),
    };
  }

  /// Runs `dart analyze` on the specified file and returns diagnostics.
  Future<Map<String, dynamic>> _toolAnalyzeFile(
    Map<String, dynamic> arguments,
  ) async {
    final filePath = _resolvePath(arguments['file_path'] as String?);
    final file = File(filePath);

    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final result = await Process.run(
      'dart',
      ['analyze', '--format=json', filePath],
      workingDirectory: projectRoot,
    );

    final stdout = result.stdout as String;
    final stderr = result.stderr as String;

    Map<String, dynamic>? diagnosticsJson;
    try {
      diagnosticsJson = jsonDecode(stdout) as Map<String, dynamic>?;
    } catch (_) {
      // dart analyze may not always produce JSON; fall back to raw output.
    }

    return {
      'file_path': filePath,
      'exit_code': result.exitCode,
      'diagnostics': diagnosticsJson,
      'raw_output': stdout,
      'stderr': stderr.isNotEmpty ? stderr : null,
    };
  }

  /// Applies a code fix by replacing [originalCode] with [replacementCode]
  /// starting at [lineNumber] in the target file.
  Future<Map<String, dynamic>> _toolApplyFix(
    Map<String, dynamic> arguments,
  ) async {
    final filePath = _resolvePath(arguments['file_path'] as String?);
    final lineNumber = arguments['line_number'] as int;
    final originalCode = arguments['original_code'] as String;
    final replacementCode = arguments['replacement_code'] as String;

    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final lines = await file.readAsLines();

    if (lineNumber < 1 || lineNumber > lines.length) {
      throw RangeError('line_number $lineNumber is out of range '
          '(1..${lines.length})');
    }

    // Reconstruct the file content, find the original snippet starting at the
    // given line, and replace it.
    final content = await file.readAsString();
    final originalLines = originalCode.split('\n');

    // Build the exact substring we expect starting at the target line.
    final targetStartIndex = lines
        .sublist(0, lineNumber - 1)
        .fold<int>(0, (sum, l) => sum + l.length + 1); // +1 for newline

    final regionEnd = targetStartIndex + originalCode.length;
    final actualSnippet = content.substring(
      targetStartIndex,
      regionEnd.clamp(0, content.length),
    );

    if (actualSnippet.trimRight() != originalCode.trimRight()) {
      // Fall back to a simple string search across the whole file.
      if (!content.contains(originalCode)) {
        return {
          'success': false,
          'file_path': filePath,
          'message': 'Original code snippet not found in file.',
        };
      }
      final updatedContent =
          content.replaceFirst(originalCode, replacementCode);
      await file.writeAsString(updatedContent);
    } else {
      final updatedContent = content.replaceRange(
        targetStartIndex,
        targetStartIndex + originalCode.length,
        replacementCode,
      );
      await file.writeAsString(updatedContent);
    }

    _log.info('Applied fix to $filePath at line $lineNumber '
        '(${originalLines.length} line(s) replaced)');

    return {
      'success': true,
      'file_path': filePath,
      'line_number': lineNumber,
      'lines_replaced': originalLines.length,
    };
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Resolves a file path that may be relative to [projectRoot].
  String _resolvePath(String? path) {
    if (path == null || path.isEmpty) {
      throw ArgumentError('file_path is required');
    }
    if (path.startsWith('/')) return path;
    return '$projectRoot/$path';
  }

  void _sendResponse(Map<String, dynamic> response) {
    final encoded = jsonEncode(response);
    stdout.writeln(encoded);
  }

  Map<String, dynamic> _successResponse({
    required dynamic id,
    required Map<String, dynamic> result,
  }) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    };
  }

  Map<String, dynamic> _errorResponse({
    required dynamic id,
    required int code,
    required String message,
  }) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'error': {
        'code': code,
        'message': message,
      },
    };
  }
}

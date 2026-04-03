/// Standalone MCP Server for AutoCure Self-Healing Agent.
///
/// Run with: dart run tools/mcp_server/bin/server.dart
///
/// This server exposes the following tools via MCP protocol:
/// - get_widget_tree: Retrieve the Flutter widget tree
/// - get_source_code: Read Dart source files
/// - analyze_file: Run dart analyze on a file
/// - apply_fix: Apply a code fix to a file
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String serverName = 'autocure-mcp-server';
const String serverVersion = '1.0.0';

void main() async {
  final server = McpServer();
  await server.start();
}

class McpServer {
  final String projectRoot;
  final int _requestId = 0;

  McpServer({String? projectRoot})
      : projectRoot = projectRoot ?? Directory.current.path;

  Future<void> start() async {
    stderr.writeln('[$serverName] Starting MCP server...');
    stderr.writeln('[$serverName] Project root: $projectRoot');

    await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      try {
        final request = jsonDecode(line) as Map<String, dynamic>;
        final response = await _handleRequest(request);
        if (response != null) {
          stdout.writeln(jsonEncode(response));
        }
      } catch (e) {
        stderr.writeln('[$serverName] Error: $e');
        stdout.writeln(jsonEncode({
          'jsonrpc': '2.0',
          'id': _requestId,
          'error': {'code': -32603, 'message': e.toString()},
        }));
      }
    }
  }

  Future<Map<String, dynamic>?> _handleRequest(Map<String, dynamic> request) async {
    final method = request['method'] as String?;
    final id = request['id'];
    final params = request['params'] as Map<String, dynamic>? ?? {};

    switch (method) {
      case 'initialize':
        return _jsonRpcResponse(id, {
          'protocolVersion': '2024-11-05',
          'capabilities': {
            'tools': {'listChanged': false},
          },
          'serverInfo': {
            'name': serverName,
            'version': serverVersion,
          },
        });

      case 'initialized':
        return null; // Notification, no response

      case 'tools/list':
        return _jsonRpcResponse(id, {
          'tools': [
            {
              'name': 'get_widget_tree',
              'description': 'Get the Flutter widget tree from a running app via VM service',
              'inputSchema': {
                'type': 'object',
                'properties': {
                  'vm_service_uri': {
                    'type': 'string',
                    'description': 'VM service WebSocket URI',
                  },
                },
                'required': ['vm_service_uri'],
              },
            },
            {
              'name': 'get_source_code',
              'description': 'Read a Dart source file with line numbers',
              'inputSchema': {
                'type': 'object',
                'properties': {
                  'file_path': {
                    'type': 'string',
                    'description': 'Path to the Dart source file',
                  },
                  'start_line': {
                    'type': 'integer',
                    'description': 'Start line number (1-based)',
                  },
                  'end_line': {
                    'type': 'integer',
                    'description': 'End line number (1-based)',
                  },
                },
                'required': ['file_path'],
              },
            },
            {
              'name': 'analyze_file',
              'description': 'Run dart analyze on a specific file',
              'inputSchema': {
                'type': 'object',
                'properties': {
                  'file_path': {
                    'type': 'string',
                    'description': 'Path to the Dart file to analyze',
                  },
                },
                'required': ['file_path'],
              },
            },
            {
              'name': 'apply_fix',
              'description': 'Apply a code fix to a Dart source file',
              'inputSchema': {
                'type': 'object',
                'properties': {
                  'file_path': {'type': 'string', 'description': 'Target file path'},
                  'line_number': {'type': 'integer', 'description': 'Line number to fix'},
                  'original_code': {'type': 'string', 'description': 'Original code to replace'},
                  'replacement_code': {'type': 'string', 'description': 'New code to insert'},
                },
                'required': ['file_path', 'original_code', 'replacement_code'],
              },
            },
          ],
        });

      case 'tools/call':
        final toolName = params['name'] as String;
        final args = params['arguments'] as Map<String, dynamic>? ?? {};
        return _jsonRpcResponse(id, await _callTool(toolName, args));

      default:
        return _jsonRpcResponse(id, null,
            error: {'code': -32601, 'message': 'Method not found: $method'});
    }
  }

  Future<Map<String, dynamic>> _callTool(
      String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'get_widget_tree':
        return _getWidgetTree(args['vm_service_uri'] as String);
      case 'get_source_code':
        return _getSourceCode(
          args['file_path'] as String,
          startLine: args['start_line'] as int?,
          endLine: args['end_line'] as int?,
        );
      case 'analyze_file':
        return _analyzeFile(args['file_path'] as String);
      case 'apply_fix':
        return _applyFix(
          args['file_path'] as String,
          args['original_code'] as String,
          args['replacement_code'] as String,
        );
      default:
        return {
          'content': [
            {'type': 'text', 'text': 'Unknown tool: $name'}
          ],
          'isError': true,
        };
    }
  }

  Future<Map<String, dynamic>> _getWidgetTree(String vmServiceUri) async {
    try {
      // Connect to VM service and get widget tree via ext.flutter.inspector
      await Process.run('flutter', [
        'run',
        '--machine',
      ], workingDirectory: projectRoot);

      return {
        'content': [
          {
            'type': 'text',
            'text': 'Widget tree retrieval requires active VM service connection.\n'
                'URI: $vmServiceUri\n'
                'Use the runtime agent for live widget tree inspection.',
          }
        ],
      };
    } catch (e) {
      return {
        'content': [
          {'type': 'text', 'text': 'Error getting widget tree: $e'}
        ],
        'isError': true,
      };
    }
  }

  Future<Map<String, dynamic>> _getSourceCode(String filePath,
      {int? startLine, int? endLine}) async {
    try {
      final resolvedPath = filePath.startsWith('/')
          ? filePath
          : '$projectRoot/$filePath';
      final file = File(resolvedPath);

      if (!await file.exists()) {
        return {
          'content': [
            {'type': 'text', 'text': 'File not found: $resolvedPath'}
          ],
          'isError': true,
        };
      }

      final lines = await file.readAsLines();
      final start = (startLine ?? 1) - 1;
      final end = endLine ?? lines.length;
      final clampedEnd = end.clamp(start, lines.length);

      final buffer = StringBuffer();
      for (var i = start; i < clampedEnd; i++) {
        buffer.writeln('${(i + 1).toString().padLeft(4)} | ${lines[i]}');
      }

      return {
        'content': [
          {
            'type': 'text',
            'text': buffer.toString(),
          }
        ],
      };
    } catch (e) {
      return {
        'content': [
          {'type': 'text', 'text': 'Error reading file: $e'}
        ],
        'isError': true,
      };
    }
  }

  Future<Map<String, dynamic>> _analyzeFile(String filePath) async {
    try {
      final result = await Process.run(
        'dart',
        ['analyze', filePath],
        workingDirectory: projectRoot,
      );

      return {
        'content': [
          {
            'type': 'text',
            'text': 'Exit code: ${result.exitCode}\n'
                'stdout:\n${result.stdout}\n'
                'stderr:\n${result.stderr}',
          }
        ],
      };
    } catch (e) {
      return {
        'content': [
          {'type': 'text', 'text': 'Error running analysis: $e'}
        ],
        'isError': true,
      };
    }
  }

  Future<Map<String, dynamic>> _applyFix(
      String filePath, String originalCode, String replacementCode) async {
    try {
      final resolvedPath = filePath.startsWith('/')
          ? filePath
          : '$projectRoot/$filePath';
      final file = File(resolvedPath);
      final content = await file.readAsString();

      if (!content.contains(originalCode)) {
        return {
          'content': [
            {'type': 'text', 'text': 'Original code not found in file'}
          ],
          'isError': true,
        };
      }

      // Create backup
      final backupPath = '$resolvedPath.bak';
      await file.copy(backupPath);

      // Apply fix
      final newContent = content.replaceFirst(originalCode, replacementCode);
      await file.writeAsString(newContent);

      return {
        'content': [
          {
            'type': 'text',
            'text': 'Fix applied successfully.\n'
                'Backup saved to: $backupPath\n'
                'Changed: ${originalCode.length} chars -> ${replacementCode.length} chars',
          }
        ],
      };
    } catch (e) {
      return {
        'content': [
          {'type': 'text', 'text': 'Error applying fix: $e'}
        ],
        'isError': true,
      };
    }
  }

  Map<String, dynamic> _jsonRpcResponse(dynamic id, dynamic result,
      {Map<String, dynamic>? error}) {
    final response = <String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
    };
    if (error != null) {
      response['error'] = error;
    } else {
      response['result'] = result;
    }
    return response;
  }
}

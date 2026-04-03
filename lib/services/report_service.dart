import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../models/agent_status.dart';
import '../models/error_report.dart';
import '../models/fix_record.dart';

/// Exports agent data as JSON or CSV reports.
class ReportService {
  final _log = Logger('ReportService');
  final String projectRoot;

  ReportService({required this.projectRoot});

  String get _reportsDir => p.join(projectRoot, 'reports');

  /// Export a full agent report as JSON.
  Future<String> exportJson({
    required AgentStatus status,
    required List<ErrorReport> errors,
    required List<FixRecord> fixes,
  }) async {
    final dir = Directory(_reportsDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final path = p.join(_reportsDir, 'autocure_report_$timestamp.json');

    final report = {
      'generated_at': DateTime.now().toIso8601String(),
      'agent_status': status.toJson(),
      'summary': {
        'total_errors': errors.length,
        'total_fixes': fixes.length,
        'verified_fixes': fixes.where((f) =>
            f.status == FixStatus.verified ||
            f.status == FixStatus.prCreated ||
            f.status == FixStatus.merged).length,
        'failed_fixes': fixes.where((f) => f.status == FixStatus.failed).length,
        'success_rate': status.successRate,
      },
      'error_breakdown': _errorBreakdown(errors),
      'errors': errors.map((e) => e.toJson()).toList(),
      'fixes': fixes.map((f) => f.toJson()).toList(),
    };

    await File(path).writeAsString(
        const JsonEncoder.withIndent('  ').convert(report));
    _log.info('JSON report exported to $path');
    return path;
  }

  /// Export errors and fixes as CSV.
  Future<String> exportCsv({
    required List<ErrorReport> errors,
    required List<FixRecord> fixes,
  }) async {
    final dir = Directory(_reportsDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    // Export errors CSV
    final errorsPath = p.join(_reportsDir, 'errors_$timestamp.csv');
    final errorsBuffer = StringBuffer()
      ..writeln('id,type,severity,message,source_file,source_line,timestamp');
    for (final e in errors) {
      errorsBuffer.writeln(
        '${_csvEscape(e.id)},'
        '${_csvEscape(e.errorType)},'
        '${e.severity.name},'
        '${_csvEscape(e.message)},'
        '${_csvEscape(e.sourceFile ?? '')},'
        '${e.sourceLine ?? ''},'
        '${e.timestamp.toIso8601String()}',
      );
    }
    await File(errorsPath).writeAsString(errorsBuffer.toString());

    // Export fixes CSV
    final fixesPath = p.join(_reportsDir, 'fixes_$timestamp.csv');
    final fixesBuffer = StringBuffer()
      ..writeln('id,error_id,description,file,line,status,analysis_passed,applied_at,verified_at,pr_url');
    for (final f in fixes) {
      fixesBuffer.writeln(
        '${_csvEscape(f.id)},'
        '${_csvEscape(f.errorReportId)},'
        '${_csvEscape(f.description)},'
        '${_csvEscape(f.filePath)},'
        '${f.lineNumber},'
        '${f.status.name},'
        '${f.analysisPassed},'
        '${f.appliedAt.toIso8601String()},'
        '${f.verifiedAt?.toIso8601String() ?? ''},'
        '${_csvEscape(f.prUrl ?? '')}',
      );
    }
    await File(fixesPath).writeAsString(fixesBuffer.toString());

    _log.info('CSV reports exported to $errorsPath and $fixesPath');
    return _reportsDir;
  }

  Map<String, int> _errorBreakdown(List<ErrorReport> errors) {
    final breakdown = <String, int>{};
    for (final e in errors) {
      breakdown[e.errorType] = (breakdown[e.errorType] ?? 0) + 1;
    }
    return breakdown;
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

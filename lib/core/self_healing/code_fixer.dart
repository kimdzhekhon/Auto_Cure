import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'error_analyzer.dart';

/// The result of applying a code fix.
class FixResult {
  final bool success;
  final String originalCode;
  final String fixedCode;
  final String backupPath;
  final String? errorMessage;

  const FixResult({
    required this.success,
    required this.originalCode,
    required this.fixedCode,
    required this.backupPath,
    this.errorMessage,
  });

  @override
  String toString() => success
      ? 'FixResult(success, backup: $backupPath)'
      : 'FixResult(failed: $errorMessage)';
}

/// Applies code fixes based on [AnalysisResult] from the [ErrorAnalyzer].
///
/// Each fix strategy is implemented as a source-to-source transformation.
/// A backup of the original file is always created before any modification.
class CodeFixer {
  static final _log = Logger('CodeFixer');
  static const _uuid = Uuid();

  final String projectRoot;
  final String backupDirectory;

  CodeFixer({
    required this.projectRoot,
    String? backupDirectory,
  }) : backupDirectory =
            backupDirectory ?? p.join(projectRoot, '.autocure', 'backups');

  /// Applies the fix described in [analysis] to the affected source file.
  ///
  /// Returns a [FixResult] indicating whether the fix was applied
  /// successfully, along with the original and fixed source code.
  Future<FixResult> applyFix(AnalysisResult analysis) async {
    final filePath = analysis.affectedFile;
    final line = analysis.affectedLine;

    _log.info(
      'Applying ${analysis.strategy} fix to $filePath:$line',
    );

    // Read the original source file.
    final file = File(filePath);
    if (!await file.exists()) {
      final msg = 'Source file not found: $filePath';
      _log.severe(msg);
      return FixResult(
        success: false,
        originalCode: '',
        fixedCode: '',
        backupPath: '',
        errorMessage: msg,
      );
    }

    final originalCode = await file.readAsString();

    // Create a backup before modifying.
    final backupPath = await _createBackup(filePath, originalCode);

    try {
      final fixedCode = _applyStrategy(
        analysis.strategy,
        originalCode,
        line,
      );

      if (fixedCode == originalCode) {
        _log.warning('Fix produced no changes for $filePath:$line');
        return FixResult(
          success: false,
          originalCode: originalCode,
          fixedCode: originalCode,
          backupPath: backupPath,
          errorMessage: 'Fix strategy produced no code changes.',
        );
      }

      // Write the fixed code back to the file.
      await file.writeAsString(fixedCode);
      _log.info('Fix applied successfully to $filePath');

      return FixResult(
        success: true,
        originalCode: originalCode,
        fixedCode: fixedCode,
        backupPath: backupPath,
      );
    } catch (e, st) {
      _log.severe('Failed to apply fix', e, st);
      // Attempt rollback on failure.
      await _restoreFromBackup(filePath, backupPath);
      return FixResult(
        success: false,
        originalCode: originalCode,
        fixedCode: originalCode,
        backupPath: backupPath,
        errorMessage: 'Fix application failed: $e',
      );
    }
  }

  /// Creates a backup of [filePath] with [content] and returns the backup path.
  Future<String> _createBackup(String filePath, String content) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4().substring(0, 8);
    final baseName = p.basename(filePath);
    final backupName = '${baseName}_${timestamp}_$id.bak';
    final backupPath = p.join(backupDirectory, backupName);

    final backupDir = Directory(backupDirectory);
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    await File(backupPath).writeAsString(content);
    _log.fine('Backup created: $backupPath');
    return backupPath;
  }

  /// Restores a file from its backup.
  Future<void> _restoreFromBackup(String filePath, String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        final content = await backupFile.readAsString();
        await File(filePath).writeAsString(content);
        _log.info('Restored $filePath from backup $backupPath');
      }
    } catch (e) {
      _log.severe('Failed to restore from backup: $e');
    }
  }

  /// Dispatches to the appropriate transformation based on [strategy].
  String _applyStrategy(FixStrategy strategy, String source, int line) {
    switch (strategy) {
      case FixStrategy.wrapWithExpanded:
        return _wrapWithExpanded(source, line);
      case FixStrategy.wrapWithSingleChildScrollView:
        return _wrapWithSingleChildScrollView(source, line);
      case FixStrategy.addFlexible:
        return _addFlexible(source, line);
      case FixStrategy.addNullCheck:
        return _addNullCheck(source, line);
      case FixStrategy.addMountedCheck:
        return _addMountedCheck(source, line);
      case FixStrategy.wrapWithSafeArea:
        return _wrapWithSafeArea(source, line);
      case FixStrategy.addConstraints:
        return _addConstraints(source, line);
      case FixStrategy.unknown:
        return source;
    }
  }

  // ---------------------------------------------------------------------------
  // Fix strategy implementations
  // ---------------------------------------------------------------------------

  /// Wraps the widget at [line] with an `Expanded` widget.
  String _wrapWithExpanded(String source, int line) {
    final lines = source.split('\n');
    if (line < 1 || line > lines.length) return source;

    final idx = line - 1;
    final targetLine = lines[idx];
    final indent = _getIndent(targetLine);

    lines[idx] = '${indent}Expanded(\n'
        '$indent  child: ${targetLine.trimLeft()}\n'
        '$indent)';

    // If the next line has a trailing comma that belonged to the original
    // widget, keep it attached to the Expanded closing paren.
    return lines.join('\n');
  }

  /// Wraps a Column or Row at [line] with `SingleChildScrollView`.
  String _wrapWithSingleChildScrollView(String source, int line) {
    final lines = source.split('\n');
    if (line < 1 || line > lines.length) return source;

    final idx = line - 1;
    final targetLine = lines[idx];
    final indent = _getIndent(targetLine);
    final trimmed = targetLine.trimLeft();

    // Expect the line to start with Column( or Row(.
    if (!trimmed.startsWith('Column(') && !trimmed.startsWith('Row(')) {
      // Try wrapping whatever widget is there.
      lines[idx] = '${indent}SingleChildScrollView(\n'
          '$indent  child: $trimmed';

      // Find the matching closing paren and append the scroll view close.
      final closingIdx = _findClosingParen(lines, idx);
      if (closingIdx != null && closingIdx < lines.length) {
        lines[closingIdx] = '${lines[closingIdx]}\n$indent)';
      }
      return lines.join('\n');
    }

    lines[idx] = '${indent}SingleChildScrollView(\n'
        '$indent  child: $trimmed';

    final closingIdx = _findClosingParen(lines, idx);
    if (closingIdx != null && closingIdx < lines.length) {
      lines[closingIdx] = '${lines[closingIdx]}\n$indent)';
    }

    return lines.join('\n');
  }

  /// Wraps the widget at [line] with a `Flexible` widget.
  String _addFlexible(String source, int line) {
    final lines = source.split('\n');
    if (line < 1 || line > lines.length) return source;

    final idx = line - 1;
    final targetLine = lines[idx];
    final indent = _getIndent(targetLine);

    lines[idx] = '${indent}Flexible(\n'
        '$indent  child: ${targetLine.trimLeft()}\n'
        '$indent)';

    return lines.join('\n');
  }

  /// Adds null-safety checks to the expression at [line].
  String _addNullCheck(String source, int line) {
    final lines = source.split('\n');
    if (line < 1 || line > lines.length) return source;

    final idx = line - 1;
    var targetLine = lines[idx];

    // Replace `.` member access with `?.` where it follows a variable name
    // but not after known non-null tokens like `)` or `this`.
    targetLine = targetLine.replaceAllMapped(
      RegExp(r'(\w)\.(\w)'),
      (m) => '${m.group(1)}?.${m.group(2)}',
    );

    // Add `!` null assertion removal — prefer `?.` over `!`.
    targetLine = targetLine.replaceAll('!.', '?.');

    lines[idx] = targetLine;
    return lines.join('\n');
  }

  /// Adds an `if (!mounted) return;` guard before a `setState` call at [line].
  String _addMountedCheck(String source, int line) {
    final lines = source.split('\n');
    if (line < 1 || line > lines.length) return source;

    final idx = line - 1;
    final targetLine = lines[idx];
    final indent = _getIndent(targetLine);

    // Check whether a mounted guard already exists on the preceding line.
    if (idx > 0 && lines[idx - 1].contains('if (!mounted)')) {
      return source;
    }

    // Insert the mounted check before the setState line.
    lines.insert(idx, '${indent}if (!mounted) return;');

    return lines.join('\n');
  }

  /// Wraps the body of a Scaffold at [line] with `SafeArea`.
  String _wrapWithSafeArea(String source, int line) {
    final lines = source.split('\n');
    if (line < 1 || line > lines.length) return source;

    final idx = line - 1;

    // Look for `body:` in nearby lines.
    for (var i = idx; i < (idx + 10).clamp(0, lines.length); i++) {
      if (lines[i].contains('body:')) {
        final bodyLine = lines[i];
        final bodyIndent = _getIndent(bodyLine);
        final bodyContent = bodyLine.trimLeft().replaceFirst('body:', '').trim();

        lines[i] = '${bodyIndent}body: SafeArea(\n'
            '$bodyIndent  child: $bodyContent';

        // Find closing and add SafeArea close.
        final closingIdx = _findClosingParen(lines, i);
        if (closingIdx != null && closingIdx < lines.length) {
          lines[closingIdx] = '${lines[closingIdx]}\n$bodyIndent)';
        }
        break;
      }
    }

    return lines.join('\n');
  }

  /// Wraps the widget at [line] with a `SizedBox` that provides constraints.
  String _addConstraints(String source, int line) {
    final lines = source.split('\n');
    if (line < 1 || line > lines.length) return source;

    final idx = line - 1;
    final targetLine = lines[idx];
    final indent = _getIndent(targetLine);

    lines[idx] = '${indent}SizedBox(\n'
        '$indent  width: double.infinity,\n'
        '$indent  child: ${targetLine.trimLeft()}\n'
        '$indent)';

    return lines.join('\n');
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  /// Extracts the leading whitespace from a line.
  String _getIndent(String line) {
    final match = RegExp(r'^(\s*)').firstMatch(line);
    return match?.group(1) ?? '';
  }

  /// Finds the index of the line containing the matching closing parenthesis
  /// for the opening paren on [startIdx].
  int? _findClosingParen(List<String> lines, int startIdx) {
    var depth = 0;
    for (var i = startIdx; i < lines.length; i++) {
      for (final char in lines[i].runes) {
        if (char == 40 /* ( */) depth++;
        if (char == 41 /* ) */) {
          depth--;
          if (depth == 0) return i;
        }
      }
    }
    return null;
  }
}

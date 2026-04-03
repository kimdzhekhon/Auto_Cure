import 'package:autocure/models/error_report.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// The result of analyzing an error report.
class AnalysisResult {
  final String rootCause;
  final String suggestedFix;
  final double confidence;
  final String affectedFile;
  final int affectedLine;
  final FixStrategy strategy;

  const AnalysisResult({
    required this.rootCause,
    required this.suggestedFix,
    required this.confidence,
    required this.affectedFile,
    required this.affectedLine,
    required this.strategy,
  });

  @override
  String toString() =>
      'AnalysisResult(rootCause: $rootCause, file: $affectedFile:$affectedLine, '
      'confidence: ${(confidence * 100).toStringAsFixed(1)}%, strategy: $strategy)';
}

/// Available fix strategies that can be applied to resolve errors.
enum FixStrategy {
  wrapWithExpanded,
  wrapWithSingleChildScrollView,
  addFlexible,
  addNullCheck,
  addMountedCheck,
  wrapWithSafeArea,
  addConstraints,
  unknown,
}

/// Pattern definition for a known error type.
class _ErrorPattern {
  final RegExp pattern;
  final FixStrategy strategy;
  final String causeTemplate;
  final double baseConfidence;

  const _ErrorPattern({
    required this.pattern,
    required this.strategy,
    required this.causeTemplate,
    required this.baseConfidence,
  });
}

/// Analyzes [ErrorReport] instances to determine root causes and suggest fixes.
///
/// The analyzer maintains a registry of known error patterns and their
/// associated fix strategies. It parses stack traces to locate the exact
/// source file and line where the error originated.
class ErrorAnalyzer {
  static final _log = Logger('ErrorAnalyzer');

  final String projectRoot;

  /// Known error patterns mapped to their fix strategies.
  static final List<_ErrorPattern> _knownPatterns = [
    _ErrorPattern(
      pattern: RegExp(r'A RenderFlex overflowed by [\d.]+ pixels'),
      strategy: FixStrategy.wrapWithExpanded,
      causeTemplate:
          'RenderFlex overflow: a child of Row/Column/Flex exceeds the '
          'available space. The parent widget is missing an Expanded, '
          'Flexible, or SingleChildScrollView wrapper.',
      baseConfidence: 0.85,
    ),
    _ErrorPattern(
      pattern: RegExp(r'overflowed by [\d.]+ pixels on the (right|bottom)'),
      strategy: FixStrategy.wrapWithSingleChildScrollView,
      causeTemplate:
          'Content overflow on the {1} side. The widget tree requires a '
          'SingleChildScrollView to accommodate dynamic content.',
      baseConfidence: 0.80,
    ),
    _ErrorPattern(
      pattern: RegExp(
        r"Null check operator used on a null value|NoSuchMethodError: The method '.+' was called on null",
      ),
      strategy: FixStrategy.addNullCheck,
      causeTemplate:
          'Null reference: a value expected to be non-null was null at '
          'runtime. The null source needs a safety check or default value.',
      baseConfidence: 0.75,
    ),
    _ErrorPattern(
      pattern: RegExp(
        r"type 'Null' is not a subtype of type '.+'",
      ),
      strategy: FixStrategy.addNullCheck,
      causeTemplate:
          'Type cast failure due to null value. A nullable type is being '
          'used where a non-nullable type is expected.',
      baseConfidence: 0.70,
    ),
    _ErrorPattern(
      pattern: RegExp(r'setState\(\) called after dispose\(\)'),
      strategy: FixStrategy.addMountedCheck,
      causeTemplate:
          'setState called after dispose: an asynchronous operation '
          'completed after the widget was removed from the tree. The async '
          'callback needs a mounted guard or cancellation.',
      baseConfidence: 0.90,
    ),
    _ErrorPattern(
      pattern: RegExp(
        r'The following assertion was thrown during layout:.*bottom overflow',
        dotAll: true,
      ),
      strategy: FixStrategy.wrapWithSafeArea,
      causeTemplate:
          'Layout overflow near screen edges. The widget tree may need a '
          'SafeArea wrapper to respect system UI insets.',
      baseConfidence: 0.65,
    ),
    _ErrorPattern(
      pattern: RegExp(r'RenderBox was not laid out|has no size'),
      strategy: FixStrategy.addConstraints,
      causeTemplate:
          'Unconstrained render box: a widget has no intrinsic size and '
          'received unbounded constraints. It needs explicit sizing via '
          'SizedBox or ConstrainedBox.',
      baseConfidence: 0.70,
    ),
  ];

  ErrorAnalyzer({required this.projectRoot});

  /// Analyzes an [ErrorReport] and returns an [AnalysisResult] describing
  /// the root cause, a suggested code diff, and the affected source location.
  ///
  /// Returns `null` if the error does not match any known pattern.
  Future<AnalysisResult?> analyze(ErrorReport report) async {
    _log.info('Analyzing error: ${report.message.take(120)}...');

    final matchedPattern = _matchPattern(report.message);
    if (matchedPattern == null) {
      _log.warning('No known pattern matched for: ${report.message}');
      return null;
    }

    final sourceLocation = _parseStackTrace(report.stackTrace);
    if (sourceLocation == null) {
      _log.warning('Could not extract source location from stack trace.');
      return null;
    }

    final rootCause = _buildRootCause(matchedPattern, report);
    final suggestedFix = _buildSuggestedFix(matchedPattern.strategy, sourceLocation);
    final confidence = _calculateConfidence(matchedPattern, report, sourceLocation);

    final result = AnalysisResult(
      rootCause: rootCause,
      suggestedFix: suggestedFix,
      confidence: confidence,
      affectedFile: sourceLocation.file,
      affectedLine: sourceLocation.line,
      strategy: matchedPattern.strategy,
    );

    _log.info('Analysis complete: $result');
    return result;
  }

  /// Matches the error message against known patterns.
  _ErrorPattern? _matchPattern(String message) {
    for (final pattern in _knownPatterns) {
      if (pattern.pattern.hasMatch(message)) {
        _log.fine('Matched pattern: ${pattern.strategy}');
        return pattern;
      }
    }
    return null;
  }

  /// Parses a stack trace string to extract the first project-relative
  /// source file and line number.
  _SourceLocation? _parseStackTrace(String stackTrace) {
    // Dart stack trace frames look like:
    //   #0      MyWidget.build (package:myapp/widgets/my_widget.dart:42:15)
    //   #1      StatelessElement.build (package:flutter/src/widgets/framework.dart:4701:28)
    final framePattern = RegExp(
      r'#\d+\s+.+\s+\(package:([^)]+):(\d+)(?::\d+)?\)',
    );

    for (final line in stackTrace.split('\n')) {
      final match = framePattern.firstMatch(line);
      if (match == null) continue;

      final packagePath = match.group(1)!;
      final lineNumber = int.parse(match.group(2)!);

      // Convert package path to a file system path relative to projectRoot.
      final filePath = p.join(projectRoot, 'lib', packagePath);

      // Skip frames from Flutter/Dart SDK internals.
      if (packagePath.startsWith('flutter/') ||
          packagePath.startsWith('dart:')) {
        continue;
      }

      _log.fine('Resolved source location: $filePath:$lineNumber');
      return _SourceLocation(file: filePath, line: lineNumber);
    }

    // Fallback: try to parse file:line patterns like
    //   file:///path/to/file.dart:42:15
    final filePattern = RegExp(r'file://(/[^:]+):(\d+)');
    for (final line in stackTrace.split('\n')) {
      final match = filePattern.firstMatch(line);
      if (match == null) continue;

      final filePath = match.group(1)!;
      final lineNumber = int.parse(match.group(2)!);

      if (filePath.startsWith(projectRoot)) {
        return _SourceLocation(file: filePath, line: lineNumber);
      }
    }

    return null;
  }

  /// Constructs a human-readable root cause description from the matched
  /// pattern and the original error report.
  String _buildRootCause(_ErrorPattern pattern, ErrorReport report) {
    var cause = pattern.causeTemplate;

    // For overflow errors, extract the overflow direction if present.
    final directionMatch =
        RegExp(r'on the (right|bottom|left|top)').firstMatch(report.message);
    if (directionMatch != null) {
      cause = cause.replaceAll('{1}', directionMatch.group(1)!);
    }

    // For null errors, attempt to identify the null variable from the trace.
    if (pattern.strategy == FixStrategy.addNullCheck) {
      final nullSource = _traceNullSource(report.stackTrace);
      if (nullSource != null) {
        cause += ' Likely null source: $nullSource.';
      }
    }

    // For setState-after-dispose, identify the async operation.
    if (pattern.strategy == FixStrategy.addMountedCheck) {
      final asyncOp = _identifyAsyncOperation(report.stackTrace);
      if (asyncOp != null) {
        cause += ' The async operation that needs cancellation: $asyncOp.';
      }
    }

    return cause;
  }

  /// Attempts to identify the variable or expression that was null by
  /// examining the stack trace for common patterns.
  String? _traceNullSource(String stackTrace) {
    // Look for patterns like "The method 'foo' was called on null"
    final methodMatch = RegExp(
      r"The method '(\w+)' was called on null",
    ).firstMatch(stackTrace);
    if (methodMatch != null) {
      return 'receiver of .${methodMatch.group(1)}() is null';
    }

    // Look for field access patterns in the top frame.
    final fieldMatch = RegExp(
      r"NoSuchMethodError:.*'(\w+)'",
    ).firstMatch(stackTrace);
    if (fieldMatch != null) {
      return 'access to .${fieldMatch.group(1)} on a null object';
    }

    return null;
  }

  /// Identifies the async operation that triggered setState after dispose
  /// by looking for Future, Timer, or Stream patterns in the stack trace.
  String? _identifyAsyncOperation(String stackTrace) {
    final patterns = <RegExp, String>{
      RegExp(r'Future\.delayed'): 'Future.delayed callback',
      RegExp(r'Timer\._handleTimeout'): 'Timer callback',
      RegExp(r'Stream.*listen'): 'Stream subscription',
      RegExp(r'_AsyncAwaitCompleter'): 'async/await continuation',
      RegExp(r'http.*\.get|http.*\.post|http.*\.fetch'):
          'HTTP request callback',
      RegExp(r'Animation.*addListener'): 'Animation listener',
    };

    for (final entry in patterns.entries) {
      if (entry.key.hasMatch(stackTrace)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Generates a suggested code diff string for the given fix strategy.
  String _buildSuggestedFix(FixStrategy strategy, _SourceLocation location) {
    switch (strategy) {
      case FixStrategy.wrapWithExpanded:
        return '''
--- a/${p.relative(location.file, from: projectRoot)}
+++ b/${p.relative(location.file, from: projectRoot)}
@@ -${location.line},1 +${location.line},3 @@
-  child,
+  Expanded(
+    child: child,
+  ),''';

      case FixStrategy.wrapWithSingleChildScrollView:
        return '''
--- a/${p.relative(location.file, from: projectRoot)}
+++ b/${p.relative(location.file, from: projectRoot)}
@@ -${location.line},1 +${location.line},3 @@
-  Column(
+  SingleChildScrollView(
+    child: Column(
+      // ... existing children ...
+    ),
+  ),''';

      case FixStrategy.addFlexible:
        return '''
--- a/${p.relative(location.file, from: projectRoot)}
+++ b/${p.relative(location.file, from: projectRoot)}
@@ -${location.line},1 +${location.line},3 @@
-  child,
+  Flexible(
+    child: child,
+  ),''';

      case FixStrategy.addNullCheck:
        return '''
--- a/${p.relative(location.file, from: projectRoot)}
+++ b/${p.relative(location.file, from: projectRoot)}
@@ -${location.line},1 +${location.line},3 @@
-  value.property
+  value?.property ?? defaultValue''';

      case FixStrategy.addMountedCheck:
        return '''
--- a/${p.relative(location.file, from: projectRoot)}
+++ b/${p.relative(location.file, from: projectRoot)}
@@ -${location.line},1 +${location.line},3 @@
-  setState(() {
+  if (!mounted) return;
+  setState(() {''';

      case FixStrategy.wrapWithSafeArea:
        return '''
--- a/${p.relative(location.file, from: projectRoot)}
+++ b/${p.relative(location.file, from: projectRoot)}
@@ -${location.line},1 +${location.line},3 @@
-  Scaffold(
+  Scaffold(
+    body: SafeArea(
+      child: // ... existing body ...
+    ),
+  ),''';

      case FixStrategy.addConstraints:
        return '''
--- a/${p.relative(location.file, from: projectRoot)}
+++ b/${p.relative(location.file, from: projectRoot)}
@@ -${location.line},1 +${location.line},5 @@
-  widget,
+  SizedBox(
+    width: double.infinity,
+    child: widget,
+  ),''';

      case FixStrategy.unknown:
        return '// No automated fix available. Manual intervention required.';
    }
  }

  /// Calculates a confidence score based on pattern match quality, stack
  /// trace completeness, and whether the affected file is within the project.
  double _calculateConfidence(
    _ErrorPattern pattern,
    ErrorReport report,
    _SourceLocation location,
  ) {
    var confidence = pattern.baseConfidence;

    // Boost confidence if the affected file is within the project root.
    if (location.file.startsWith(projectRoot)) {
      confidence += 0.05;
    }

    // Reduce confidence if the stack trace is short (less context).
    final frameCount = report.stackTrace.split('\n').length;
    if (frameCount < 3) {
      confidence -= 0.15;
    }

    // Reduce confidence if the error message is very generic.
    if (report.message.length < 30) {
      confidence -= 0.10;
    }

    return confidence.clamp(0.0, 1.0);
  }
}

/// Internal representation of a source code location.
class _SourceLocation {
  final String file;
  final int line;

  const _SourceLocation({required this.file, required this.line});
}

/// Extension to take a prefix of a string safely.
extension _StringTake on String {
  String take(int n) => length <= n ? this : substring(0, n);
}

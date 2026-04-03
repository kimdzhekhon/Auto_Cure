import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:process_run/process_run.dart';

/// The result of verifying a code fix.
class VerificationResult {
  final bool analysisPassed;
  final bool testsPassed;
  final List<String> errors;
  final bool rollbackPerformed;

  const VerificationResult({
    required this.analysisPassed,
    required this.testsPassed,
    required this.errors,
    required this.rollbackPerformed,
  });

  /// Whether the fix is fully verified (analysis clean and tests green).
  bool get isVerified => analysisPassed && testsPassed && !rollbackPerformed;

  @override
  String toString() =>
      'VerificationResult(analysis: $analysisPassed, tests: $testsPassed, '
      'errors: ${errors.length}, rollback: $rollbackPerformed)';
}

/// Verifies that a code fix does not introduce new errors.
///
/// Runs `dart analyze` on the modified file and executes related test files.
/// If verification fails, the original file is restored from its backup.
class VerificationService {
  static final _log = Logger('VerificationService');

  final String projectRoot;

  VerificationService({required this.projectRoot});

  /// Verifies the fix applied to [filePath] by running static analysis and
  /// related tests. If analysis fails, rolls back from [backupPath].
  ///
  /// Returns a [VerificationResult] summarizing the outcome.
  Future<VerificationResult> verifyFix(
    String filePath,
    String backupPath,
  ) async {
    _log.info('Verifying fix for $filePath');

    final errors = <String>[];

    // Step 1: Run static analysis.
    final analysisPassed = await runAnalysis(filePath);
    if (!analysisPassed) {
      errors.add('Static analysis found new errors in $filePath.');
      _log.warning('Analysis failed for $filePath — rolling back.');
      await rollback(filePath, backupPath);
      return VerificationResult(
        analysisPassed: false,
        testsPassed: false,
        errors: errors,
        rollbackPerformed: true,
      );
    }

    // Step 2: Find and run related tests.
    final testsPassed = await findAndRunTests(filePath);
    if (!testsPassed) {
      errors.add('One or more related tests failed after applying fix.');
      _log.warning('Tests failed for $filePath — rolling back.');
      await rollback(filePath, backupPath);
      return VerificationResult(
        analysisPassed: true,
        testsPassed: false,
        errors: errors,
        rollbackPerformed: true,
      );
    }

    _log.info('Verification passed for $filePath');
    return VerificationResult(
      analysisPassed: true,
      testsPassed: true,
      errors: errors,
      rollbackPerformed: false,
    );
  }

  /// Runs `dart analyze` on [filePath] and returns `true` if no errors
  /// are reported.
  Future<bool> runAnalysis(String filePath) async {
    _log.fine('Running dart analyze on $filePath');

    try {
      final result = await Shell(
        workingDirectory: projectRoot,
        throwOnError: false,
      ).run('dart analyze $filePath');

      final output = result.map((r) => r.stdout.toString()).join('\n');
      final errOutput = result.map((r) => r.stderr.toString()).join('\n');

      // `dart analyze` exits with 0 when there are no errors.
      final exitCode = result.last.exitCode;
      if (exitCode == 0) {
        _log.fine('Analysis clean for $filePath');
        return true;
      }

      // Check whether the output contains actual errors (not just infos/warnings).
      final hasErrors = RegExp(r'\d+ error[s]? found').hasMatch(output) ||
          RegExp(r'error •').hasMatch(output);

      if (hasErrors) {
        _log.warning('Analysis errors:\n$output\n$errOutput');
        return false;
      }

      // Warnings and infos are acceptable.
      _log.fine('Analysis passed with warnings for $filePath');
      return true;
    } catch (e, st) {
      _log.severe('Failed to run dart analyze', e, st);
      return false;
    }
  }

  /// Locates test files related to [filePath] and runs them via
  /// `flutter test`. Returns `true` if all tests pass.
  ///
  /// Test file discovery follows these conventions:
  /// - `lib/foo/bar.dart` -> `test/foo/bar_test.dart`
  /// - `lib/foo/bar.dart` -> `test/foo_test.dart`
  Future<bool> findAndRunTests(String filePath) async {
    final testFiles = _findRelatedTestFiles(filePath);

    if (testFiles.isEmpty) {
      _log.info('No related test files found for $filePath — skipping tests.');
      return true;
    }

    _log.fine('Found ${testFiles.length} related test file(s): $testFiles');

    var allPassed = true;

    for (final testFile in testFiles) {
      _log.fine('Running flutter test $testFile');
      try {
        final result = await Shell(
          workingDirectory: projectRoot,
          throwOnError: false,
        ).run('flutter test $testFile');

        final exitCode = result.last.exitCode;
        if (exitCode != 0) {
          final output = result.map((r) => r.stdout.toString()).join('\n');
          _log.warning('Test failed: $testFile\n$output');
          allPassed = false;
        } else {
          _log.fine('Test passed: $testFile');
        }
      } catch (e, st) {
        _log.severe('Failed to run tests for $testFile', e, st);
        allPassed = false;
      }
    }

    return allPassed;
  }

  /// Restores [filePath] from [backupPath].
  Future<void> rollback(String filePath, String backupPath) async {
    _log.info('Rolling back $filePath from $backupPath');

    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        _log.severe('Backup file not found: $backupPath — cannot rollback.');
        return;
      }

      final content = await backupFile.readAsString();
      await File(filePath).writeAsString(content);
      _log.info('Rollback complete for $filePath');
    } catch (e, st) {
      _log.severe('Rollback failed for $filePath', e, st);
      rethrow;
    }
  }

  /// Discovers test files that are related to [filePath].
  List<String> _findRelatedTestFiles(String filePath) {
    // Convert lib path to test path.
    // e.g., lib/widgets/my_widget.dart -> test/widgets/my_widget_test.dart
    final relativePath = p.relative(filePath, from: projectRoot);
    if (!relativePath.startsWith('lib${p.separator}')) {
      _log.fine('File is not under lib/ — cannot infer test location.');
      return [];
    }

    final withoutLib = relativePath.replaceFirst('lib${p.separator}', '');
    final candidates = <String>[];

    // Primary convention: mirror path under test/ with _test suffix.
    final baseName = p.basenameWithoutExtension(withoutLib);
    final dirName = p.dirname(withoutLib);
    final primaryTestPath = p.join(
      projectRoot,
      'test',
      dirName,
      '${baseName}_test.dart',
    );
    candidates.add(primaryTestPath);

    // Secondary convention: test file named after the directory.
    if (dirName != '.') {
      final dirTestPath = p.join(
        projectRoot,
        'test',
        '${p.basename(dirName)}_test.dart',
      );
      candidates.add(dirTestPath);
    }

    // Tertiary: widget_test.dart at test root (common in Flutter projects).
    candidates.add(p.join(projectRoot, 'test', 'widget_test.dart'));

    // Filter to files that actually exist.
    return candidates.where((path) => File(path).existsSync()).toList();
  }
}

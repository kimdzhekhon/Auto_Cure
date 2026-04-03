import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:process_run/process_run.dart';

import '../models/fix_record.dart';

/// Configuration for the CI/CD integration service.
class CiCdConfig {
  final String githubToken;
  final String repoOwner;
  final String repoName;
  final String baseBranch;
  final String? ciWebhookUrl;

  const CiCdConfig({
    required this.githubToken,
    required this.repoOwner,
    required this.repoName,
    this.baseBranch = 'main',
    this.ciWebhookUrl,
  });

  String get repoSlug => '$repoOwner/$repoName';
  Uri get apiBase => Uri.parse('https://api.github.com/repos/$repoSlug');
}

class CiCdException implements Exception {
  final String message;
  const CiCdException(this.message);

  @override
  String toString() => 'CiCdException: $message';
}

/// Service that integrates the self-healing agent with CI/CD pipelines.
class CiCdService {
  final CiCdConfig? config;
  final Logger _log = Logger('CiCdService');
  final http.Client _httpClient;
  final String projectRoot;

  CiCdService({
    required this.projectRoot,
    this.config,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  // ---------------------------------------------------------------------------
  // Branch management
  // ---------------------------------------------------------------------------

  Future<String> createFixBranch(FixRecord fix) async {
    final errorType = _sanitizeBranchSegment(fix.description);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final branchName = 'autofix/$errorType-$timestamp';

    _log.info('Creating fix branch: $branchName');

    final baseBranch = config?.baseBranch ?? 'main';
    await _git(['fetch', 'origin', baseBranch]);
    await _git(['checkout', '-b', branchName]);

    _log.info('Branch $branchName created successfully');
    return branchName;
  }

  // ---------------------------------------------------------------------------
  // Commit
  // ---------------------------------------------------------------------------

  Future<void> commitFix(FixRecord fix) async {
    _log.info('Committing fix: ${fix.description}');

    await _git(['add', '-A']);

    final message = '[AutoCure] ${fix.description}\n\n'
        'File: ${fix.filePath}:${fix.lineNumber}\n'
        'Error ID: ${fix.errorReportId}\n'
        'Analysis passed: ${fix.analysisPassed}';
    await _git(['commit', '-m', message]);

    final branch = await _currentBranch();
    await _git(['push', '-u', 'origin', branch]);

    _log.info('Fix committed and pushed to $branch');
  }

  // ---------------------------------------------------------------------------
  // Pull request
  // ---------------------------------------------------------------------------

  Future<String?> createPullRequest(FixRecord fix) async {
    if (config == null) {
      _log.warning('No CI/CD config, attempting gh CLI fallback');
      return _createPrViaCli(fix);
    }

    final branch = await _currentBranch();
    final title = '[AutoCure] ${fix.description}';
    final body = _buildPrBody(fix);

    _log.info('Creating PR from $branch -> ${config!.baseBranch}');

    final uri = config!.apiBase.resolve('pulls');
    final response = await _githubPost(uri, body: {
      'title': title,
      'body': body,
      'head': branch,
      'base': config!.baseBranch,
    });

    if (response.statusCode != 201) {
      _log.severe('Failed to create PR: ${response.statusCode} ${response.body}');
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final prUrl = data['html_url'] as String;
    _log.info('PR created: $prUrl');
    return prUrl;
  }

  Future<String?> _createPrViaCli(FixRecord fix) async {
    try {
      final result = await Process.run('gh', [
        'pr',
        'create',
        '--title',
        '[AutoCure] ${fix.description}',
        '--body',
        _buildPrBody(fix),
      ], workingDirectory: projectRoot);

      if (result.exitCode == 0) {
        final url = (result.stdout as String).trim();
        _log.info('PR created via gh CLI: $url');
        return url;
      }
      _log.severe('gh pr create failed: ${result.stderr}');
      return null;
    } catch (e) {
      _log.severe('gh CLI not available: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CI trigger
  // ---------------------------------------------------------------------------

  Future<void> triggerCI(String branch) async {
    _log.info('Triggering CI for branch $branch');

    if (config != null) {
      await _triggerGitHubActionsWorkflow(branch);
    }

    if (config?.ciWebhookUrl != null) {
      await _triggerWebhook(branch);
    }
  }

  // ---------------------------------------------------------------------------
  // Repository info
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getRepoInfo() async {
    if (config == null) return null;

    final response = await _githubGet(config!.apiBase);
    if (response.statusCode != 200) return null;

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<String> _git(List<String> args) async {
    final result = await runExecutableArguments(
      'git',
      args,
      workingDirectory: projectRoot,
    );

    final stdout = result.stdout.toString().trim();
    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      throw CiCdException('git ${args.join(' ')} failed: $stderr');
    }
    return stdout;
  }

  Future<String> _currentBranch() async {
    return _git(['rev-parse', '--abbrev-ref', 'HEAD']);
  }

  Map<String, String> get _githubHeaders => {
        'Authorization': 'Bearer ${config!.githubToken}',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  Future<http.Response> _githubGet(Uri uri) {
    return _httpClient.get(uri, headers: _githubHeaders);
  }

  Future<http.Response> _githubPost(Uri uri, {required Map<String, dynamic> body}) {
    return _httpClient.post(
      uri,
      headers: {..._githubHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  Future<void> _triggerGitHubActionsWorkflow(String branch) async {
    final uri = config!.apiBase.resolve('actions/workflows/self-heal.yml/dispatches');
    final response = await _githubPost(uri, body: {'ref': branch});

    if (response.statusCode == 204) {
      _log.info('GitHub Actions dispatched for $branch');
    } else {
      _log.warning('GitHub Actions dispatch returned ${response.statusCode}');
    }
  }

  Future<void> _triggerWebhook(String branch) async {
    final webhookUrl = config!.ciWebhookUrl;
    if (webhookUrl == null) return;

    final response = await _httpClient.post(
      Uri.parse(webhookUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'branch': branch,
        'triggered_by': 'autocure',
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _log.info('CI webhook triggered for $branch');
    }
  }

  String _buildPrBody(FixRecord fix) {
    return '''## AutoCure Self-Healing Fix

This PR was generated automatically by the AutoCure self-healing agent.

### Fix Details

| Field | Value |
|-------|-------|
| **Description** | ${fix.description} |
| **File** | `${fix.filePath}:${fix.lineNumber}` |
| **Status** | ${fix.status.name} |
| **Analysis Passed** | ${fix.analysisPassed ? 'Yes' : 'No'} |
| **Applied At** | ${fix.appliedAt.toIso8601String()} |

### Code Changes

**Original:**
```dart
${fix.originalCode}
```

**Fixed:**
```dart
${fix.fixedCode}
```

### Tests Run
${fix.testsRun.map((t) => '- $t').join('\n')}

---
> Generated by [AutoCure](https://github.com/autocure) self-healing agent
''';
  }

  String _sanitizeBranchSegment(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  void dispose() {
    _httpClient.close();
  }
}

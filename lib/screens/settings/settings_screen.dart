import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _vmUriCtrl;
  late TextEditingController _tokenCtrl;
  late TextEditingController _ownerCtrl;
  late TextEditingController _repoCtrl;
  late TextEditingController _branchCtrl;
  late TextEditingController _webhookCtrl;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsService>().settings;
    _vmUriCtrl = TextEditingController(text: s.vmServiceUri ?? '');
    _tokenCtrl = TextEditingController(text: s.githubToken ?? '');
    _ownerCtrl = TextEditingController(text: s.repoOwner ?? '');
    _repoCtrl = TextEditingController(text: s.repoName ?? '');
    _branchCtrl = TextEditingController(text: s.baseBranch);
    _webhookCtrl = TextEditingController(text: s.ciWebhookUrl ?? '');
  }

  @override
  void dispose() {
    _vmUriCtrl.dispose();
    _tokenCtrl.dispose();
    _ownerCtrl.dispose();
    _repoCtrl.dispose();
    _branchCtrl.dispose();
    _webhookCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, service, _) {
        final s = service.settings;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              TextButton.icon(
                onPressed: () => _resetSettings(service),
                icon: const Icon(Icons.restore),
                label: const Text('Reset'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionHeader('VM Service Connection'),
              _textField(
                controller: _vmUriCtrl,
                label: 'VM Service URI',
                hint: 'ws://127.0.0.1:XXXXX/XXXXX=/ws',
                icon: Icons.cable,
              ),
              const SizedBox(height: 24),
              _sectionHeader('GitHub / CI/CD'),
              _textField(
                controller: _tokenCtrl,
                label: 'GitHub Token',
                hint: 'ghp_xxxxxxxxxxxx',
                icon: Icons.key,
                obscure: true,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _textField(
                      controller: _ownerCtrl,
                      label: 'Repo Owner',
                      hint: 'username',
                      icon: Icons.person,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _textField(
                      controller: _repoCtrl,
                      label: 'Repo Name',
                      hint: 'my-app',
                      icon: Icons.folder,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _textField(
                controller: _branchCtrl,
                label: 'Base Branch',
                hint: 'main',
                icon: Icons.account_tree,
              ),
              const SizedBox(height: 8),
              _textField(
                controller: _webhookCtrl,
                label: 'CI Webhook URL (optional)',
                hint: 'https://semaphore.ci/...',
                icon: Icons.webhook,
              ),
              const SizedBox(height: 24),
              _sectionHeader('Agent Behavior'),
              SwitchListTile(
                title: const Text('Auto-Fix Enabled'),
                subtitle:
                    const Text('Automatically apply fixes when errors are detected'),
                value: s.autoFixEnabled,
                onChanged: (v) => _update(s.copyWith(autoFixEnabled: v)),
              ),
              SwitchListTile(
                title: const Text('Auto-Create PR'),
                subtitle: const Text(
                    'Automatically create pull requests after verification'),
                value: s.autoCreatePR,
                onChanged: (v) => _update(s.copyWith(autoCreatePR: v)),
              ),
              ListTile(
                title: const Text('Max Concurrent Fixes'),
                subtitle: Text('${s.maxConcurrentFixes}'),
                trailing: DropdownButton<int>(
                  value: s.maxConcurrentFixes,
                  items: [1, 2, 3, 5]
                      .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                      .toList(),
                  onChanged: (v) =>
                      v != null ? _update(s.copyWith(maxConcurrentFixes: v)) : null,
                ),
              ),
              ListTile(
                title: const Text('Min Confidence Threshold'),
                subtitle: Slider(
                  value: s.minConfidenceThreshold,
                  min: 0.3,
                  max: 1.0,
                  divisions: 14,
                  label: '${(s.minConfidenceThreshold * 100).toInt()}%',
                  onChanged: (v) =>
                      _update(s.copyWith(minConfidenceThreshold: v)),
                ),
                trailing: Text(
                  '${(s.minConfidenceThreshold * 100).toInt()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              _sectionHeader('Notifications'),
              SwitchListTile(
                title: const Text('Push Notifications'),
                value: s.notificationsEnabled,
                onChanged: (v) =>
                    _update(s.copyWith(notificationsEnabled: v)),
              ),
              SwitchListTile(
                title: const Text('Sound Alerts'),
                value: s.soundEnabled,
                onChanged: (v) => _update(s.copyWith(soundEnabled: v)),
              ),
              const SizedBox(height: 24),
              _sectionHeader('Data Retention'),
              ListTile(
                title: const Text('Error Retention'),
                subtitle: Text('${s.errorRetentionDays} days'),
                trailing: DropdownButton<int>(
                  value: s.errorRetentionDays,
                  items: [7, 14, 30, 60, 90]
                      .map((v) =>
                          DropdownMenuItem(value: v, child: Text('$v days')))
                      .toList(),
                  onChanged: (v) =>
                      v != null ? _update(s.copyWith(errorRetentionDays: v)) : null,
                ),
              ),
              ListTile(
                title: const Text('Fix Retention'),
                subtitle: Text('${s.fixRetentionDays} days'),
                trailing: DropdownButton<int>(
                  value: s.fixRetentionDays,
                  items: [30, 60, 90, 180, 365]
                      .map((v) =>
                          DropdownMenuItem(value: v, child: Text('$v days')))
                      .toList(),
                  onChanged: (v) =>
                      v != null ? _update(s.copyWith(fixRetentionDays: v)) : null,
                ),
              ),
              const SizedBox(height: 24),
              _sectionHeader('Connection'),
              ListTile(
                title: const Text('Health Check Interval'),
                trailing: DropdownButton<int>(
                  value: s.healthCheckInterval.inSeconds,
                  items: [10, 15, 30, 60]
                      .map((v) =>
                          DropdownMenuItem(value: v, child: Text('${v}s')))
                      .toList(),
                  onChanged: (v) => v != null
                      ? _update(s.copyWith(
                          healthCheckInterval: Duration(seconds: v)))
                      : null,
                ),
              ),
              ListTile(
                title: const Text('Max Reconnect Attempts'),
                trailing: DropdownButton<int>(
                  value: s.maxReconnectAttempts,
                  items: [3, 5, 10, 20]
                      .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                      .toList(),
                  onChanged: (v) =>
                      v != null ? _update(s.copyWith(maxReconnectAttempts: v)) : null,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _saveAll,
                icon: const Icon(Icons.save),
                label: const Text('Save All Settings'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  void _update(AgentSettings settings) {
    context.read<SettingsService>().update(settings);
  }

  void _saveAll() {
    final service = context.read<SettingsService>();
    final s = service.settings.copyWith(
      vmServiceUri:
          _vmUriCtrl.text.isNotEmpty ? _vmUriCtrl.text : null,
      githubToken:
          _tokenCtrl.text.isNotEmpty ? _tokenCtrl.text : null,
      repoOwner: _ownerCtrl.text.isNotEmpty ? _ownerCtrl.text : null,
      repoName: _repoCtrl.text.isNotEmpty ? _repoCtrl.text : null,
      baseBranch: _branchCtrl.text.isNotEmpty ? _branchCtrl.text : 'main',
      ciWebhookUrl:
          _webhookCtrl.text.isNotEmpty ? _webhookCtrl.text : null,
    );
    service.update(s);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetSettings(SettingsService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('This will reset all settings to defaults.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              service.reset();
              _vmUriCtrl.clear();
              _tokenCtrl.clear();
              _ownerCtrl.clear();
              _repoCtrl.clear();
              _branchCtrl.text = 'main';
              _webhookCtrl.clear();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';

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
            actions: [
              TextButton.icon(
                onPressed: () => _resetSettings(service),
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('Reset'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionHeader(context, 'VM Service Connection', Icons.cable_rounded),
              const SizedBox(height: 8),
              _textField(
                controller: _vmUriCtrl,
                label: 'VM Service URI',
                hint: 'ws://127.0.0.1:XXXXX/XXXXX=/ws',
                icon: Icons.link_rounded,
              ),
              const SizedBox(height: 28),
              _sectionHeader(context, 'GitHub / CI/CD', Icons.code_rounded),
              const SizedBox(height: 8),
              _textField(
                controller: _tokenCtrl,
                label: 'GitHub Token',
                hint: 'ghp_xxxxxxxxxxxx',
                icon: Icons.key_rounded,
                obscure: true,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _textField(
                      controller: _ownerCtrl,
                      label: 'Repo Owner',
                      hint: 'username',
                      icon: Icons.person_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _textField(
                      controller: _repoCtrl,
                      label: 'Repo Name',
                      hint: 'my-app',
                      icon: Icons.folder_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _textField(
                controller: _branchCtrl,
                label: 'Base Branch',
                hint: 'main',
                icon: Icons.account_tree_rounded,
              ),
              const SizedBox(height: 10),
              _textField(
                controller: _webhookCtrl,
                label: 'CI Webhook URL',
                hint: 'https://semaphore.ci/...',
                icon: Icons.webhook_rounded,
              ),
              const SizedBox(height: 28),
              _sectionHeader(context, 'Agent Behavior', Icons.smart_toy_rounded),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Auto-Fix Enabled', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Automatically apply fixes when errors are detected'),
                      value: s.autoFixEnabled,
                      onChanged: (v) => _update(s.copyWith(autoFixEnabled: v)),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: const Text('Auto-Create PR', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Automatically create pull requests after verification'),
                      value: s.autoCreatePR,
                      onChanged: (v) => _update(s.copyWith(autoCreatePR: v)),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      title: const Text('Max Concurrent Fixes', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${s.maxConcurrentFixes}'),
                      trailing: DropdownButton<int>(
                        value: s.maxConcurrentFixes,
                        underline: const SizedBox(),
                        items: [1, 2, 3, 5]
                            .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                            .toList(),
                        onChanged: (v) =>
                            v != null ? _update(s.copyWith(maxConcurrentFixes: v)) : null,
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      title: const Text('Min Confidence', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppColors.primary,
                          thumbColor: AppColors.primary,
                          inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
                          overlayColor: AppColors.primary.withValues(alpha: 0.1),
                        ),
                        child: Slider(
                          value: s.minConfidenceThreshold,
                          min: 0.3,
                          max: 1.0,
                          divisions: 14,
                          label: '${(s.minConfidenceThreshold * 100).toInt()}%',
                          onChanged: (v) =>
                              _update(s.copyWith(minConfidenceThreshold: v)),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(s.minConfidenceThreshold * 100).toInt()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _sectionHeader(context, 'Notifications', Icons.notifications_rounded),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                      value: s.notificationsEnabled,
                      onChanged: (v) =>
                          _update(s.copyWith(notificationsEnabled: v)),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: const Text('Sound Alerts', style: TextStyle(fontWeight: FontWeight.w600)),
                      value: s.soundEnabled,
                      onChanged: (v) => _update(s.copyWith(soundEnabled: v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _sectionHeader(context, 'Data Retention', Icons.storage_rounded),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Error Retention', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${s.errorRetentionDays} days'),
                      trailing: DropdownButton<int>(
                        value: s.errorRetentionDays,
                        underline: const SizedBox(),
                        items: [7, 14, 30, 60, 90]
                            .map((v) =>
                                DropdownMenuItem(value: v, child: Text('$v days')))
                            .toList(),
                        onChanged: (v) =>
                            v != null ? _update(s.copyWith(errorRetentionDays: v)) : null,
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      title: const Text('Fix Retention', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${s.fixRetentionDays} days'),
                      trailing: DropdownButton<int>(
                        value: s.fixRetentionDays,
                        underline: const SizedBox(),
                        items: [30, 60, 90, 180, 365]
                            .map((v) =>
                                DropdownMenuItem(value: v, child: Text('$v days')))
                            .toList(),
                        onChanged: (v) =>
                            v != null ? _update(s.copyWith(fixRetentionDays: v)) : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _sectionHeader(context, 'Connection', Icons.wifi_rounded),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Health Check Interval', style: TextStyle(fontWeight: FontWeight.w600)),
                      trailing: DropdownButton<int>(
                        value: s.healthCheckInterval.inSeconds,
                        underline: const SizedBox(),
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
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      title: const Text('Max Reconnect Attempts', style: TextStyle(fontWeight: FontWeight.w600)),
                      trailing: DropdownButton<int>(
                        value: s.maxReconnectAttempts,
                        underline: const SizedBox(),
                        items: [3, 5, 10, 20]
                            .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                            .toList(),
                        onChanged: (v) =>
                            v != null ? _update(s.copyWith(maxReconnectAttempts: v)) : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _saveAll,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text(
                  'Save All Settings',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
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
        prefixIcon: icon != null
            ? Icon(icon, size: 20)
            : null,
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
      const SnackBar(content: Text('Settings saved successfully')),
    );
  }

  void _resetSettings(SettingsService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restore_rounded, color: AppColors.warning, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Reset Settings'),
          ],
        ),
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
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

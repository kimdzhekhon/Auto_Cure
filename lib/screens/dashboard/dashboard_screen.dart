import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/agent_status.dart';
import '../../models/fix_record.dart';
import '../../services/agent_provider.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../settings/settings_screen.dart';
import 'widgets/status_card.dart';
import 'widgets/fix_history_list.dart';
import 'widgets/error_log_view.dart';
import 'widgets/agent_status_widget.dart';
import 'widgets/stats_chart.dart';
import 'widgets/timeline_view.dart';
import 'widgets/notification_bell.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _vmUriController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AgentProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _vmUriController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AgentProvider>(
      builder: (context, provider, _) {
        final status = provider.status;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_fix_high, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('AutoCure'),
              ],
            ),
            actions: [
              _buildConnectionIndicator(status),
              const SizedBox(width: 4),
              const NotificationBell(),
              _buildAgentToggle(provider),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => _onMenuAction(value, provider),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings_outlined),
                      title: Text('Settings'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export_json',
                    child: ListTile(
                      leading: Icon(Icons.file_download_outlined),
                      title: Text('Export JSON'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export_csv',
                    child: ListTile(
                      leading: Icon(Icons.table_chart_outlined),
                      title: Text('Export CSV'),
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
                Tab(icon: Icon(Icons.timeline_outlined), text: 'Timeline'),
                Tab(icon: Icon(Icons.bug_report_outlined), text: 'Errors'),
                Tab(icon: Icon(Icons.auto_fix_high_outlined), text: 'Fixes'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(provider),
              TimelineView(
                errors: provider.errors,
                fixes: provider.fixes,
              ),
              ErrorLogView(errors: provider.errors),
              FixHistoryList(fixes: provider.fixes),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showConnectDialog(context, provider),
            icon: Icon(provider.isRunning ? Icons.refresh_rounded : Icons.play_arrow_rounded),
            label: Text(
              provider.isRunning ? 'Reconnect' : 'Start Agent',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewTab(AgentProvider provider) {
    final status = provider.status;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AgentStatusWidget(status: status),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatusCard(
                  title: 'Errors',
                  value: '${status.totalErrorsDetected}',
                  icon: Icons.bug_report_rounded,
                  color: AppColors.error,
                  bgColor: AppColors.error.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatusCard(
                  title: 'Fixes',
                  value: '${status.totalFixesApplied}',
                  icon: Icons.build_rounded,
                  color: AppColors.warning,
                  bgColor: AppColors.warning.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatusCard(
                  title: 'Verified',
                  value: '${status.totalFixesVerified}',
                  icon: Icons.verified_rounded,
                  color: AppColors.success,
                  bgColor: AppColors.success.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatusCard(
                  title: 'PRs',
                  value: '${status.totalPRsCreated}',
                  icon: Icons.merge_rounded,
                  color: AppColors.info,
                  bgColor: AppColors.info.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StatsChart(
            successRate: status.successRate,
            totalErrors: status.totalErrorsDetected,
            totalFixes: status.totalFixesApplied,
            totalVerified: status.totalFixesVerified,
          ),
          const SizedBox(height: 16),
          if (provider.fixes.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Recent Fixes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _tabController.animateTo(3),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...provider.fixes.reversed.take(5).map(
                  (fix) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _fixColor(fix).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_fixIcon(fix), color: _fixColor(fix), size: 18),
                        ),
                        title: Text(
                          fix.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${fix.filePath}:${fix.lineNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        trailing: fix.prUrl != null
                            ? Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.link_rounded, color: AppColors.info, size: 16),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  IconData _fixIcon(FixRecord fix) {
    if (fix.status == FixStatus.verified || fix.status == FixStatus.prCreated) {
      return Icons.check_circle_rounded;
    }
    if (fix.status == FixStatus.failed) return Icons.cancel_rounded;
    return Icons.hourglass_bottom_rounded;
  }

  Color _fixColor(FixRecord fix) {
    if (fix.status == FixStatus.verified || fix.status == FixStatus.prCreated) {
      return AppColors.success;
    }
    if (fix.status == FixStatus.failed) return AppColors.error;
    return AppColors.warning;
  }

  Widget _buildConnectionIndicator(AgentStatus status) {
    final connected = status.vmServiceConnected;
    final color = connected ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'Live' : 'Off',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentToggle(AgentProvider provider) {
    return Switch(
      value: provider.isRunning,
      onChanged: (val) {
        if (val) {
          provider.startAgent();
        } else {
          provider.stopAgent();
        }
      },
    );
  }

  void _onMenuAction(String action, AgentProvider provider) {
    switch (action) {
      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      case 'export_json':
        _exportJson(provider);
      case 'export_csv':
        _exportCsv(provider);
    }
  }

  Future<void> _exportJson(AgentProvider provider) async {
    final report = ReportService(projectRoot: '.');
    final path = await report.exportJson(
      status: provider.status,
      errors: provider.errors,
      fixes: provider.fixes,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JSON report saved to $path')),
      );
    }
  }

  Future<void> _exportCsv(AgentProvider provider) async {
    final report = ReportService(projectRoot: '.');
    final dir = await report.exportCsv(
      errors: provider.errors,
      fixes: provider.fixes,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV reports saved to $dir')),
      );
    }
  }

  void _showConnectDialog(BuildContext context, AgentProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cable_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Connect to VM Service'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the VM service URI from flutter run output, '
              'or leave empty to auto-discover.',
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _vmUriController,
              decoration: const InputDecoration(
                hintText: 'ws://127.0.0.1:XXXXX/XXXXX=/ws',
                labelText: 'VM Service URI',
                prefixIcon: Icon(Icons.cable_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              final uri = _vmUriController.text.trim();
              provider.startAgent(
                vmServiceUri: uri.isNotEmpty ? uri : null,
              );
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

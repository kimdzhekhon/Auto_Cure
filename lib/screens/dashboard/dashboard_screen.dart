import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/agent_status.dart';
import '../../services/agent_provider.dart';
import 'widgets/status_card.dart';
import 'widgets/fix_history_list.dart';
import 'widgets/error_log_view.dart';
import 'widgets/agent_status_widget.dart';
import 'widgets/stats_chart.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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
            title: const Text('AutoCure Dashboard'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              _buildConnectionIndicator(status),
              const SizedBox(width: 8),
              _buildAgentToggle(provider),
              const SizedBox(width: 16),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
                Tab(icon: Icon(Icons.error_outline), text: 'Errors'),
                Tab(icon: Icon(Icons.auto_fix_high), text: 'Fix History'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(provider),
              ErrorLogView(errors: provider.errors),
              FixHistoryList(fixes: provider.fixes),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showConnectDialog(context, provider),
            icon: const Icon(Icons.play_arrow),
            label: Text(provider.isRunning ? 'Reconnect' : 'Start Agent'),
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
                  title: 'Errors Detected',
                  value: '${status.totalErrorsDetected}',
                  icon: Icons.bug_report,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatusCard(
                  title: 'Fixes Applied',
                  value: '${status.totalFixesApplied}',
                  icon: Icons.build,
                  color: Colors.orange,
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
                  icon: Icons.verified,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatusCard(
                  title: 'PRs Created',
                  value: '${status.totalPRsCreated}',
                  icon: Icons.merge,
                  color: Colors.blue,
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
            Text(
              'Recent Fixes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...provider.fixes.reversed.take(5).map(
                  (fix) => Card(
                    child: ListTile(
                      leading: Icon(
                        fix.status == FixStatus.verified ||
                                fix.status == FixStatus.prCreated
                            ? Icons.check_circle
                            : fix.status == FixStatus.failed
                                ? Icons.cancel
                                : Icons.hourglass_bottom,
                        color: fix.status == FixStatus.verified ||
                                fix.status == FixStatus.prCreated
                            ? Colors.green
                            : fix.status == FixStatus.failed
                                ? Colors.red
                                : Colors.orange,
                      ),
                      title: Text(fix.description),
                      subtitle: Text('${fix.filePath}:${fix.lineNumber}'),
                      trailing: fix.prUrl != null
                          ? const Icon(Icons.link, color: Colors.blue)
                          : null,
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionIndicator(AgentStatus status) {
    final connected = status.vmServiceConnected;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: connected ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          connected ? 'Connected' : 'Disconnected',
          style: const TextStyle(fontSize: 12),
        ),
      ],
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

  void _showConnectDialog(BuildContext context, AgentProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connect to VM Service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the VM service URI from flutter run output, '
              'or leave empty to auto-discover.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _vmUriController,
              decoration: const InputDecoration(
                hintText: 'ws://127.0.0.1:XXXXX/XXXXX=/ws',
                border: OutlineInputBorder(),
                labelText: 'VM Service URI',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              final uri = _vmUriController.text.trim();
              provider.startAgent(
                vmServiceUri: uri.isNotEmpty ? uri : null,
              );
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

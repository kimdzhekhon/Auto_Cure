import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/agent_status.dart';

class AgentStatusWidget extends StatelessWidget {
  final AgentStatus status;

  const AgentStatusWidget({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStateChip(status.state),
                const Spacer(),
                Text(
                  'Success Rate: ${(status.successRate * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _successRateColor(status.successRate),
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (status.currentTask != null)
              Row(
                children: [
                  if (status.state == AgentState.analyzing ||
                      status.state == AgentState.fixing ||
                      status.state == AgentState.verifying)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      status.currentTask!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                _infoChip(
                  Icons.timer,
                  'Started: ${DateFormat.Hm().format(status.startedAt)}',
                ),
                const SizedBox(width: 12),
                _infoChip(
                  Icons.favorite,
                  'Heartbeat: ${DateFormat.Hms().format(status.lastHeartbeat)}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _connectionChip('VM Service', status.vmServiceConnected),
                const SizedBox(width: 8),
                _connectionChip('MCP Server', status.mcpServerRunning),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateChip(AgentState state) {
    final (label, color) = switch (state) {
      AgentState.idle => ('Idle', Colors.grey),
      AgentState.monitoring => ('Monitoring', Colors.green),
      AgentState.analyzing => ('Analyzing', Colors.blue),
      AgentState.fixing => ('Fixing', Colors.orange),
      AgentState.verifying => ('Verifying', Colors.purple),
      AgentState.creatingPR => ('Creating PR', Colors.teal),
      AgentState.error => ('Error', Colors.red),
      AgentState.stopped => ('Stopped', Colors.grey),
    };

    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        radius: 6,
      ),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _connectionChip(String label, bool connected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (connected ? Colors.green : Colors.red).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (connected ? Colors.green : Colors.red).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: connected ? Colors.green[700] : Colors.red[700],
            ),
          ),
        ],
      ),
    );
  }

  Color _successRateColor(double rate) {
    if (rate >= 0.8) return Colors.green;
    if (rate >= 0.5) return Colors.orange;
    return Colors.red;
  }
}

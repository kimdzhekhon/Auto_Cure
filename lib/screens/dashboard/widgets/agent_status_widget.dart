import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/agent_status.dart';
import '../../../theme/app_theme.dart';

class AgentStatusWidget extends StatelessWidget {
  final AgentStatus status;

  const AgentStatusWidget({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.cardDark, const Color(0xFF16213E)]
              : [Colors.white, const Color(0xFFF0EDFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStateChip(status.state),
              const Spacer(),
              _buildSuccessRate(context, status.successRate),
            ],
          ),
          const SizedBox(height: 16),
          if (status.currentTask != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  if (status.state == AgentState.analyzing ||
                      status.state == AgentState.fixing ||
                      status.state == AgentState.verifying)
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      status.currentTask!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (status.currentTask != null) const SizedBox(height: 14),
          Row(
            children: [
              _infoChip(
                context,
                Icons.schedule_rounded,
                DateFormat.Hm().format(status.startedAt),
              ),
              const SizedBox(width: 10),
              _infoChip(
                context,
                Icons.favorite_rounded,
                DateFormat.Hms().format(status.lastHeartbeat),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _connectionChip(context, 'VM Service', status.vmServiceConnected),
              const SizedBox(width: 8),
              _connectionChip(context, 'MCP Server', status.mcpServerRunning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStateChip(AgentState state) {
    final (label, color) = switch (state) {
      AgentState.idle => ('Idle', AppColors.idle),
      AgentState.monitoring => ('Monitoring', AppColors.monitoring),
      AgentState.analyzing => ('Analyzing', AppColors.analyzing),
      AgentState.fixing => ('Fixing', AppColors.fixing),
      AgentState.verifying => ('Verifying', AppColors.verifying),
      AgentState.creatingPR => ('Creating PR', AppColors.creatingPR),
      AgentState.error => ('Error', AppColors.error),
      AgentState.stopped => ('Stopped', AppColors.idle),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
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
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessRate(BuildContext context, double rate) {
    final color = rate >= 0.8
        ? AppColors.success
        : rate >= 0.5
            ? AppColors.warning
            : AppColors.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            value: rate,
            strokeWidth: 3,
            backgroundColor: color.withValues(alpha: 0.15),
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${(rate * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Success',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoChip(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }

  Widget _connectionChip(BuildContext context, String label, bool connected) {
    final color = connected ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

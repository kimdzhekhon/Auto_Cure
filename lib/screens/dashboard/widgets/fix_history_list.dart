import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/fix_record.dart';
import '../../../theme/app_theme.dart';

class FixHistoryList extends StatelessWidget {
  final List<FixRecord> fixes;

  const FixHistoryList({super.key, required this.fixes});

  @override
  Widget build(BuildContext context) {
    if (fixes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_fix_high_rounded, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'No fixes yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Auto-fixes will appear here when errors are resolved',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: fixes.length,
      itemBuilder: (context, index) {
        final fix = fixes[fixes.length - 1 - index];
        return _FixCard(fix: fix);
      },
    );
  }
}

class _FixCard extends StatelessWidget {
  final FixRecord fix;

  const _FixCard({required this.fix});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ExpansionTile(
          leading: _statusBadge(fix.status),
          title: Text(
            fix.description,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${fix.filePath}:${fix.lineNumber}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _statusChip(fix.status),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.schedule_rounded,
                    size: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat.yMd().add_Hms().format(fix.appliedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel(context, 'Original Code'),
                  const SizedBox(height: 6),
                  _codeBlock(
                    context,
                    fix.originalCode,
                    isDark ? const Color(0xFF2D1B1B) : const Color(0xFFFFF0F0),
                    isDark ? const Color(0xFF4A2020) : const Color(0xFFFFD7D7),
                  ),
                  const SizedBox(height: 14),
                  _sectionLabel(context, 'Fixed Code'),
                  const SizedBox(height: 6),
                  _codeBlock(
                    context,
                    fix.fixedCode,
                    isDark ? const Color(0xFF1B2D1B) : const Color(0xFFF0FFF0),
                    isDark ? const Color(0xFF204A20) : const Color(0xFFD7FFD7),
                  ),
                  if (fix.testsRun.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _sectionLabel(context, 'Tests'),
                    const SizedBox(height: 6),
                    ...fix.testsRun.map((t) => Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                fix.analysisPassed
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                size: 14,
                                color: fix.analysisPassed
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                t,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                  if (fix.prUrl != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link_rounded, size: 16, color: AppColors.info),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fix.prUrl!,
                              style: const TextStyle(
                                color: AppColors.info,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (fix.failureReason != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_rounded, size: 16, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fix.failureReason!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _codeBlock(BuildContext context, String code, Color bgColor, Color borderColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: SelectableText(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.5,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _statusBadge(FixStatus status) {
    final (icon, color) = switch (status) {
      FixStatus.pending => (Icons.hourglass_empty_rounded, AppColors.idle),
      FixStatus.analyzing => (Icons.search_rounded, AppColors.analyzing),
      FixStatus.fixing => (Icons.build_rounded, AppColors.fixing),
      FixStatus.verifying => (Icons.fact_check_rounded, AppColors.verifying),
      FixStatus.verified => (Icons.check_circle_rounded, AppColors.success),
      FixStatus.prCreated => (Icons.merge_rounded, AppColors.creatingPR),
      FixStatus.merged => (Icons.done_all_rounded, AppColors.success),
      FixStatus.failed => (Icons.cancel_rounded, AppColors.error),
      FixStatus.rolledBack => (Icons.undo_rounded, AppColors.warning),
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _statusChip(FixStatus status) {
    final (label, color) = switch (status) {
      FixStatus.pending => ('Pending', AppColors.idle),
      FixStatus.analyzing => ('Analyzing', AppColors.analyzing),
      FixStatus.fixing => ('Fixing', AppColors.fixing),
      FixStatus.verifying => ('Verifying', AppColors.verifying),
      FixStatus.verified => ('Verified', AppColors.success),
      FixStatus.prCreated => ('PR Created', AppColors.creatingPR),
      FixStatus.merged => ('Merged', AppColors.success),
      FixStatus.failed => ('Failed', AppColors.error),
      FixStatus.rolledBack => ('Rolled Back', AppColors.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

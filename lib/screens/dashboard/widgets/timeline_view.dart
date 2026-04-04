import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/error_report.dart';
import '../../../models/fix_record.dart';
import '../../../theme/app_theme.dart';

class TimelineEvent {
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final TimelineEventType type;
  final IconData icon;
  final Color color;
  final Map<String, dynamic>? data;

  TimelineEvent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.type,
    required this.icon,
    required this.color,
    this.data,
  });

  factory TimelineEvent.fromError(ErrorReport error) => TimelineEvent(
        id: error.id,
        title: 'Error: ${error.errorType}',
        subtitle: error.message,
        timestamp: error.timestamp,
        type: TimelineEventType.error,
        icon: Icons.bug_report_rounded,
        color: AppColors.error,
        data: {'severity': error.severity.name},
      );

  factory TimelineEvent.fromFix(FixRecord fix) {
    final (icon, color, label) = switch (fix.status) {
      FixStatus.verified || FixStatus.prCreated || FixStatus.merged => (
          Icons.check_circle_rounded,
          AppColors.success,
          'Fixed',
        ),
      FixStatus.failed || FixStatus.rolledBack => (
          Icons.cancel_rounded,
          AppColors.error,
          'Fix Failed',
        ),
      _ => (Icons.build_rounded, AppColors.warning, 'Fixing'),
    };

    return TimelineEvent(
      id: fix.id,
      title: '$label: ${fix.description}',
      subtitle: '${fix.filePath}:${fix.lineNumber}',
      timestamp: fix.appliedAt,
      type: TimelineEventType.fix,
      icon: icon,
      color: color,
      data: {'status': fix.status.name, 'prUrl': fix.prUrl},
    );
  }
}

enum TimelineEventType { error, fix, system }

class TimelineView extends StatelessWidget {
  final List<ErrorReport> errors;
  final List<FixRecord> fixes;

  const TimelineView({
    super.key,
    required this.errors,
    required this.fixes,
  });

  @override
  Widget build(BuildContext context) {
    final events = <TimelineEvent>[
      ...errors.map(TimelineEvent.fromError),
      ...fixes.map(TimelineEvent.fromFix),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (events.isEmpty) {
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
              child: const Icon(Icons.timeline_rounded, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'No events yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Events will appear here as the agent runs',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isFirst = index == 0;
        final isLast = index == events.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    if (!isFirst)
                      Expanded(
                        child: Container(
                          width: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                events[index - 1].color.withValues(alpha: 0.3),
                                event.color.withValues(alpha: 0.3),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: event.color,
                        boxShadow: [
                          BoxShadow(
                            color: event.color.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: event.color.withValues(alpha: 0.2),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: event.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(event.icon, size: 14, color: event.color),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: event.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            event.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat.yMd().add_Hms().format(event.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

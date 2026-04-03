import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/error_report.dart';
import '../../../models/fix_record.dart';

/// A unified event type for the timeline.
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
        icon: Icons.error_outline,
        color: Colors.red,
        data: {'severity': error.severity.name},
      );

  factory TimelineEvent.fromFix(FixRecord fix) {
    final (icon, color, label) = switch (fix.status) {
      FixStatus.verified || FixStatus.prCreated || FixStatus.merged => (
          Icons.check_circle,
          Colors.green,
          'Fixed',
        ),
      FixStatus.failed || FixStatus.rolledBack => (
          Icons.cancel,
          Colors.red,
          'Fix Failed',
        ),
      _ => (Icons.build, Colors.orange, 'Fixing'),
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

/// Displays a chronological timeline of errors and fixes.
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No events yet', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('Events will appear here as the agent runs',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isFirst = index == 0;
        final isLast = index == events.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeline line + dot
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    if (!isFirst)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: Colors.grey[300],
                        ),
                      ),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: event.color,
                        border: Border.all(
                          color: event.color.withValues(alpha: 0.3),
                          width: 3,
                        ),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: Colors.grey[300],
                        ),
                      ),
                  ],
                ),
              ),
              // Event card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(event.icon,
                                  size: 16, color: event.color),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: event.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.subtitle,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat.yMd().add_Hms().format(event.timestamp),
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[500]),
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/error_report.dart';
import '../../../theme/app_theme.dart';

class ErrorLogView extends StatelessWidget {
  final List<ErrorReport> errors;

  const ErrorLogView({super.key, required this.errors});

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.success),
            ),
            const SizedBox(height: 20),
            Text(
              'No errors detected',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'The agent is monitoring for runtime errors',
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
      itemCount: errors.length,
      itemBuilder: (context, index) {
        final error = errors[errors.length - 1 - index];
        return _ErrorCard(error: error);
      },
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final ErrorReport error;

  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ExpansionTile(
          leading: _severityBadge(error.severity),
          title: Text(
            error.errorType,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                error.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat.yMd().add_Hms().format(error.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  if (error.sourceFile != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.code_rounded, size: 12, color: AppColors.info),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${error.sourceFile}:${error.sourceLine}',
                        style: const TextStyle(fontSize: 11, color: AppColors.info),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
                  if (error.widgetPath != null) ...[
                    _sectionLabel(context, 'Widget Path'),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        error.widgetPath!,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _sectionLabel(context, 'Stack Trace'),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0D1117)
                          : const Color(0xFF1E1E2E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(
                      error.stackTrace,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppColors.accent,
                        height: 1.5,
                      ),
                    ),
                  ),
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

  Widget _severityBadge(ErrorSeverity severity) {
    final (icon, color) = switch (severity) {
      ErrorSeverity.low => (Icons.info_outline_rounded, AppColors.info),
      ErrorSeverity.medium => (Icons.warning_amber_rounded, AppColors.warning),
      ErrorSeverity.high => (Icons.error_outline_rounded, Color(0xFFE17055)),
      ErrorSeverity.critical => (Icons.dangerous_rounded, AppColors.error),
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
}

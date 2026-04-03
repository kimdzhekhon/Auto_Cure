import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/error_report.dart';

class ErrorLogView extends StatelessWidget {
  final List<ErrorReport> errors;

  const ErrorLogView({super.key, required this.errors});

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('No errors detected', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text(
              'The agent is monitoring for runtime errors',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: errors.length,
      itemBuilder: (context, index) {
        final error = errors[errors.length - 1 - index]; // newest first
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ExpansionTile(
        leading: _severityIcon(error.severity),
        title: Text(
          error.errorType,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  DateFormat.yMd().add_Hms().format(error.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                if (error.sourceFile != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${error.sourceFile}:${error.sourceLine}',
                    style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                  ),
                ],
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error.widgetPath != null) ...[
                  const Text('Widget Path:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      error.widgetPath!,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Stack Trace:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    error.stackTrace,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _severityIcon(ErrorSeverity severity) {
    final (icon, color) = switch (severity) {
      ErrorSeverity.low => (Icons.info_outline, Colors.blue),
      ErrorSeverity.medium => (Icons.warning_amber, Colors.orange),
      ErrorSeverity.high => (Icons.error_outline, Colors.deepOrange),
      ErrorSeverity.critical => (Icons.dangerous, Colors.red),
    };
    return Icon(icon, color: color);
  }
}

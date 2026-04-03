import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/fix_record.dart';

class FixHistoryList extends StatelessWidget {
  final List<FixRecord> fixes;

  const FixHistoryList({super.key, required this.fixes});

  @override
  Widget build(BuildContext context) {
    if (fixes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_fix_high, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No fixes yet', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text(
              'Auto-fixes will appear here when errors are detected and resolved',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ExpansionTile(
        leading: _statusIcon(fix.status),
        title: Text(
          fix.description,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${fix.filePath}:${fix.lineNumber}'),
            const SizedBox(height: 4),
            Row(
              children: [
                _statusChip(fix.status),
                const SizedBox(width: 8),
                Text(
                  DateFormat.yMd().add_Hms().format(fix.appliedAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
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
                const Text('Original Code:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                _codeBlock(fix.originalCode, Colors.red[50]!),
                const SizedBox(height: 12),
                const Text('Fixed Code:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                _codeBlock(fix.fixedCode, Colors.green[50]!),
                const SizedBox(height: 12),
                if (fix.testsRun.isNotEmpty) ...[
                  const Text('Tests Run:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...fix.testsRun.map((t) => Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 2),
                        child: Row(
                          children: [
                            Icon(
                              fix.analysisPassed
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              size: 14,
                              color:
                                  fix.analysisPassed ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(t, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      )),
                  const SizedBox(height: 12),
                ],
                if (fix.prUrl != null)
                  Row(
                    children: [
                      const Icon(Icons.link, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        'PR: ${fix.prUrl}',
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                if (fix.failureReason != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fix.failureReason!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.red),
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
    );
  }

  Widget _codeBlock(String code, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: SelectableText(
        code,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }

  Widget _statusIcon(FixStatus status) {
    final (icon, color) = switch (status) {
      FixStatus.pending => (Icons.hourglass_empty, Colors.grey),
      FixStatus.analyzing => (Icons.search, Colors.blue),
      FixStatus.fixing => (Icons.build, Colors.orange),
      FixStatus.verifying => (Icons.fact_check, Colors.purple),
      FixStatus.verified => (Icons.check_circle, Colors.green),
      FixStatus.prCreated => (Icons.merge, Colors.teal),
      FixStatus.merged => (Icons.done_all, Colors.green),
      FixStatus.failed => (Icons.cancel, Colors.red),
      FixStatus.rolledBack => (Icons.undo, Colors.amber),
    };
    return Icon(icon, color: color);
  }

  Widget _statusChip(FixStatus status) {
    final (label, color) = switch (status) {
      FixStatus.pending => ('Pending', Colors.grey),
      FixStatus.analyzing => ('Analyzing', Colors.blue),
      FixStatus.fixing => ('Fixing', Colors.orange),
      FixStatus.verifying => ('Verifying', Colors.purple),
      FixStatus.verified => ('Verified', Colors.green),
      FixStatus.prCreated => ('PR Created', Colors.teal),
      FixStatus.merged => ('Merged', Colors.green),
      FixStatus.failed => ('Failed', Colors.red),
      FixStatus.rolledBack => ('Rolled Back', Colors.amber),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}

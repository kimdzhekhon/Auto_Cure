import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StatsChart extends StatelessWidget {
  final double successRate;
  final int totalErrors;
  final int totalFixes;
  final int totalVerified;

  const StatsChart({
    super.key,
    required this.successRate,
    required this.totalErrors,
    required this.totalFixes,
    required this.totalVerified,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agent Performance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildPieChart(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: _buildBarChart(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _legendItem(Colors.red, 'Errors'),
                _legendItem(Colors.orange, 'Fixes'),
                _legendItem(Colors.green, 'Verified'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    final failed = totalFixes - totalVerified;
    final unfixed = totalErrors - totalFixes;

    if (totalErrors == 0) {
      return const Center(
        child: Text('No data yet', style: TextStyle(color: Colors.grey)),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 30,
        sections: [
          if (totalVerified > 0)
            PieChartSectionData(
              value: totalVerified.toDouble(),
              color: Colors.green,
              title: '$totalVerified',
              radius: 40,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          if (failed > 0)
            PieChartSectionData(
              value: failed.toDouble(),
              color: Colors.red,
              title: '$failed',
              radius: 40,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          if (unfixed > 0)
            PieChartSectionData(
              value: unfixed.toDouble(),
              color: Colors.grey,
              title: '$unfixed',
              radius: 40,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final maxVal = [totalErrors, totalFixes, totalVerified]
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final maxY = maxVal == 0 ? 10.0 : maxVal * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barGroups: [
          BarChartGroupData(x: 0, barRods: [
            BarChartRodData(
              toY: totalErrors.toDouble(),
              color: Colors.red,
              width: 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ]),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(
              toY: totalFixes.toDouble(),
              color: Colors.orange,
              width: 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ]),
          BarChartGroupData(x: 2, barRods: [
            BarChartRodData(
              toY: totalVerified.toDouble(),
              color: Colors.green,
              width: 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ]),
        ],
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final labels = ['Errors', 'Fixes', 'Verified'];
                if (value.toInt() < labels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      labels[value.toInt()],
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

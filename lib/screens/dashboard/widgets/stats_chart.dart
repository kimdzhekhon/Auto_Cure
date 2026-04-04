import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../theme/app_theme.dart';

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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildPieChart(context),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: _buildBarChart(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _legendItem(AppColors.error, 'Errors'),
                _legendItem(AppColors.warning, 'Fixes'),
                _legendItem(AppColors.success, 'Verified'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(BuildContext context) {
    final failed = totalFixes - totalVerified;
    final unfixed = totalErrors - totalFixes;

    if (totalErrors == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline_rounded, size: 32, color: AppColors.idle),
            const SizedBox(height: 8),
            Text(
              'No data',
              style: TextStyle(color: AppColors.idle, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 28,
        sections: [
          if (totalVerified > 0)
            PieChartSectionData(
              value: totalVerified.toDouble(),
              color: AppColors.success,
              title: '$totalVerified',
              radius: 42,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          if (failed > 0)
            PieChartSectionData(
              value: failed.toDouble(),
              color: AppColors.error,
              title: '$failed',
              radius: 42,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          if (unfixed > 0)
            PieChartSectionData(
              value: unfixed.toDouble(),
              color: AppColors.idle,
              title: '$unfixed',
              radius: 42,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBarChart(BuildContext context) {
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
              gradient: const LinearGradient(
                colors: [AppColors.error, Color(0xFFFF8E8E)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: 22,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ]),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(
              toY: totalFixes.toDouble(),
              gradient: const LinearGradient(
                colors: [AppColors.warning, Color(0xFFFFCC80)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: 22,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ]),
          BarChartGroupData(x: 2, barRods: [
            BarChartRodData(
              toY: totalVerified.toDouble(),
              gradient: const LinearGradient(
                colors: [AppColors.success, Color(0xFF55EFC4)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: 22,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[value.toInt()],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

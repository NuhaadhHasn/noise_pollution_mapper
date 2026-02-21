import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';

class NoiseHistoryChart extends StatelessWidget {
  final List<double> dbHistory;

  const NoiseHistoryChart({
    super.key,
    required this.dbHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: dbHistory.isEmpty
          ? const Center(
              child: Text(
                'Start measuring to see noise history',
                style: TextStyle(color: AppTheme.textGray),
              ),
            )
          : LineChart(
              _buildChartData(),
              duration: const Duration(milliseconds: 250), // Smooth animation
            ),
    );
  }

  LineChartData _buildChartData() {
    // Prepare data points
    final spots = <FlSpot>[];
    final dataToShow = dbHistory.length > 50 ? dbHistory.sublist(dbHistory.length - 50) : dbHistory;

    for (int i = 0; i < dataToShow.length; i++) {
      spots.add(FlSpot(i.toDouble(), dataToShow[i]));
    }

    return LineChartData(
      // Remove grid lines
      gridData: const FlGridData(show: false),

      // Remove axis titles
      titlesData: const FlTitlesData(show: false),

      // Remove border
      borderData: FlBorderData(show: false),

      // Min and max Y values
      minY: 0,
      maxY: 100,

      // Line and area styling
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppTheme.primaryPurple,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false), // No dots on line
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryPurple.withValues(alpha:0.5),
                AppTheme.primaryPurple.withValues(alpha:0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],

      // Touch interaction
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                '${spot.y.toStringAsFixed(1)} dB',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}

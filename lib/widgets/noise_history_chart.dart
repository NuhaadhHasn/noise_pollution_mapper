import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/theme_helper.dart';

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
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: dbHistory.isEmpty
          ? Center(
              child: Text(
                'Start measuring to see noise history',
                style: TextStyle(
                  color: ThemeHelper.getSecondaryTextColor(context),
                ),
              ),
            )
          : LineChart(
              _buildChartData(context),
              duration: const Duration(milliseconds: 250),
            ),
    );
  }

  LineChartData _buildChartData(BuildContext context) {
    final primaryColor = ThemeHelper.getPrimaryColor(context);
    
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

      // Line and area styling - theme-aware
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: primaryColor,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                primaryColor.withValues(alpha: 0.5),
                primaryColor.withValues(alpha: 0.1),
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

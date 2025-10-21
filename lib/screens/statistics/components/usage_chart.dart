import 'package:aquasense/models/billing_info.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UsageChart extends StatelessWidget {
  final List<BillingInfo> billingHistory;

  const UsageChart({super.key, required this.billingHistory});

  @override
  Widget build(BuildContext context) {
    // Sort data by date ascending to draw the line chart correctly
    final sortedHistory = List<BillingInfo>.from(billingHistory)
      ..sort((a, b) => a.date.compareTo(b.date));

    final spots = <FlSpot>[];
    for (int i = 0; i < sortedHistory.length; i++) {
      // --- REVERTED LOGIC: Use the raw reading for the graph spots ---
      spots.add(FlSpot(i.toDouble(), sortedHistory[i].reading.toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 50, // Interval for cumulative readings
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withAlpha(26),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.white.withAlpha(26),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedHistory.length) {
                  final month =
                  DateFormat.MMM().format(sortedHistory[index].date.toDate());
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8.0,
                    child: Text(month,
                        style:
                        const TextStyle(color: Colors.white70, fontSize: 10)),
                  );
                }
                return Container();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 50, // Interval for cumulative readings
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()} m³',
                    style:
                    const TextStyle(color: Colors.white70, fontSize: 10));
              },
              reservedSize: 42,
            ),
          ),
        ),
        borderData: FlBorderData(
            show: true, border: Border.all(color: Colors.white.withAlpha(26))),
        minX: 0,
        maxX: (sortedHistory.length - 1).toDouble(),
        minY: 0,
        maxY:
        _getMaxReading(sortedHistory) * 1.2, // Add some padding to the top
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: const LinearGradient(
              colors: [Colors.cyanAccent, Colors.blueAccent],
            ),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.cyanAccent.withAlpha(77),
                  Colors.blueAccent.withAlpha(0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getMaxReading(List<BillingInfo> history) {
    if (history.isEmpty) return 100; // Default max Y value
    return history
        .map((e) => e.reading)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
  }
}
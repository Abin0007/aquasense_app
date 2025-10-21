import 'package:aquasense/models/billing_info.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MiniUsageChart extends StatelessWidget {
  final List<BillingInfo> billingHistory;

  const MiniUsageChart({super.key, required this.billingHistory});

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8.0, bottom: 16),
          child: Text(
            'RECENT USAGE (LAST 6 MONTHS)',
            style: TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5),
          ),
        ),
        Container(
          height: 150,
          padding: const EdgeInsets.only(top: 16, right: 16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
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
                        final month = DateFormat.MMM()
                            .format(sortedHistory[index].date.toDate());
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 8.0,
                          child: Text(month,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 10)),
                        );
                      }
                      return Container();
                    },
                  ),
                ),
                leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (sortedHistory.length - 1).toDouble(),
              minY: 0,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  gradient: const LinearGradient(
                    colors: [Colors.cyanAccent, Colors.blueAccent],
                  ),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        Colors.cyanAccent.withAlpha(50),
                        Colors.blueAccent.withAlpha(0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
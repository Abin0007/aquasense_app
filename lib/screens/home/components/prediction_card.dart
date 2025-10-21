import 'package:flutter/material.dart';
import 'package:aquasense/services/ml_service.dart';

class PredictionCard extends StatelessWidget {
  final ConsumptionCategory category;

  const PredictionCard({super.key, required this.category});

  // Helper to get display properties based on the category
  Map<String, dynamic> _getCategoryProperties() {
    switch (category) {
      case ConsumptionCategory.efficient:
        return {
          'title': 'Efficient User',
          'subtitle': 'Your consumption is forecasted to be low. Great job!',
          'icon': Icons.eco,
          'color': Colors.greenAccent,
        };
      case ConsumptionCategory.average:
        return {
          'title': 'Average User',
          'subtitle': 'Your next month\'s consumption is predicted to be normal.',
          'icon': Icons.waves,
          'color': Colors.blueAccent,
        };
      case ConsumptionCategory.high:
        return {
          'title': 'High User',
          'subtitle': 'Your consumption is predicted to be above average.',
          'icon': Icons.water_drop,
          'color': Colors.orangeAccent,
        };
      case ConsumptionCategory.veryHigh:
        return {
          'title': 'Very High Usage Alert',
          'subtitle': 'A potential leak is detected. Your usage is unusually high.',
          'icon': Icons.warning_amber,
          'color': Colors.redAccent,
        };
      default:
        return {
          'title': 'Prediction',
          'subtitle': 'Consumption forecast will appear here.',
          'icon': Icons.bubble_chart,
          'color': Colors.grey,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final properties = _getCategoryProperties();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      sliver: SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                properties['color'].withAlpha(38),
                properties['color'].withAlpha(20),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25.0),
            border: Border.all(color: properties['color'].withAlpha(51)),
          ),
          child: Row(
            children: [
              Icon(
                properties['icon'],
                color: properties['color'],
                size: 40,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      properties['title'],
                      style: TextStyle(
                        color: properties['color'],
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      properties['subtitle'],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
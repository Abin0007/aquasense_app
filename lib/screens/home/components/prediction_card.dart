import 'package:flutter/material.dart';
import 'package:aquasense/services/ml_service.dart'; // Keep using the enum from here

class PredictionCard extends StatelessWidget {
  final ConsumptionCategory category;

  const PredictionCard({super.key, required this.category});

  // Helper to get display properties based on the category
  Map<String, dynamic> _getCategoryProperties() {
    switch (category) {
      case ConsumptionCategory.efficient:
        return {
          'title': 'Efficient User',
          'subtitle': 'Your consumption is forecasted to be low. Great job maintaining efficient water usage!',
          'icon': Icons.eco,
          'color': Colors.greenAccent,
          'explanation': 'This prediction means your average monthly water usage is low (typically 10 m³ or less based on recent history). Keep up the great work in conserving water!',
        };
      case ConsumptionCategory.average:
        return {
          'title': 'Average User',
          'subtitle': 'Your next month\'s consumption is predicted to be normal.',
          'icon': Icons.waves,
          'color': Colors.blueAccent,
          'explanation': 'This prediction indicates your average monthly water usage falls within the typical range (roughly 11-25 m³ based on recent history). Your usage is considered standard.',
        };
      case ConsumptionCategory.high:
        return {
          'title': 'High User',
          'subtitle': 'Your consumption is predicted to be above average.',
          'icon': Icons.water_drop, // Consider Icons.trending_up if more appropriate
          'color': Colors.orangeAccent,
          'explanation': 'This prediction suggests your average monthly water usage is higher than average (roughly 26-40 m³ based on recent history). Consider checking for potential wastage or ways to reduce consumption.',
        };
      case ConsumptionCategory.veryHigh:
        return {
          'title': 'Very High Usage Alert',
          'subtitle': 'Potential leak detected or unusually high usage predicted.',
          'icon': Icons.warning_amber,
          'color': Colors.redAccent,
          'explanation': 'DANGER! This prediction indicates significantly high average monthly water usage (above 40 m³ based on recent history). This could indicate a leak in your plumbing or very high water consumption. Please inspect your water fixtures and usage habits immediately. Consider reporting an issue if you suspect a leak.',
        };
    }
  }

  // Function to show the explanation dialog
  void _showExplanationDialog(BuildContext context, Map<String, dynamic> properties) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF152D4E), // Dark background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: properties['color'].withOpacity(0.5), width: 1),
          ),
          icon: Icon(properties['icon'], color: properties['color'], size: 40),
          title: Text(
            properties['title'],
            textAlign: TextAlign.center,
            style: TextStyle(
              color: properties['color'],
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            properties['explanation'],
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            TextButton(
              child: const Text('OK', style: TextStyle(color: Colors.cyanAccent, fontSize: 16)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final properties = _getCategoryProperties();

    return Padding( // Changed from SliverPadding
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      // --- WRAPPED WITH GestureDetector ---
      child: GestureDetector(
        onTap: () => _showExplanationDialog(context, properties), // Call the dialog function
        child: Container( // This Container is now the direct child of Padding
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
              // Add a subtle indicator that it's tappable
              Icon(
                Icons.info_outline,
                color: Colors.white.withAlpha(80),
                size: 20,
              ),
            ],
          ),
        ),
      ),
      // --- END WRAP ---
    );
  }
}
import 'package:aquasense/services/ml_service.dart';
import 'package:flutter/material.dart';


class AllPredictionsCard extends StatelessWidget {
  final ConsumptionCategory? consumptionCategory;
  final ResolutionTimeCategory? resolutionTimeCategory;
  final LeakageProbabilityCategory? leakageProbabilityCategory;
  final BillingAccuracyCategory? billingAccuracyCategory;
  final PeakDemandCategory? peakDemandCategory;

  const AllPredictionsCard({
    super.key,
    required this.consumptionCategory,
    required this.resolutionTimeCategory,
    required this.leakageProbabilityCategory,
    required this.billingAccuracyCategory,
    required this.peakDemandCategory,
  });

  // --- Main (KNN) Prediction Properties ---
  Map<String, dynamic> _getConsumptionProperties() {
    switch (consumptionCategory) {
      case ConsumptionCategory.efficient:
        return {
          'title': 'Efficient User',
          'subtitle': 'Your consumption is forecasted to be low. Great job maintaining efficient water usage!',
          'icon': Icons.eco,
          'color': Colors.greenAccent,
          'explanation': 'A K-Nearest Neighbors (KNN) model running in the cloud analyzed your billing history. Based on your low average consumption (e.g., < 10 m³), you are classified as an Efficient user. Keep up the great work!',
        };
      case ConsumptionCategory.average:
        return {
          'title': 'Average User',
          'subtitle': 'Your next month\'s consumption is predicted to be normal.',
          'icon': Icons.waves,
          'color': Colors.blueAccent,
          'explanation': 'A K-Nearest Neighbors (KNN) model running in the cloud analyzed your billing history. Your usage (e.g., 11-25 m³) falls within the standard range for your ward, classifying you as an Average user.',
        };
      case ConsumptionCategory.high:
        return {
          'title': 'High User',
          'subtitle': 'Your consumption is predicted to be above average.',
          'icon': Icons.water_drop,
          'color': Colors.orangeAccent,
          'explanation': 'A K-Nearest Neighbors (KNN) model running in the cloud analyzed your billing history. Your usage (e.g., 26-40 m³) is higher than average for your ward. Please be mindful of your consumption.',
        };
      case ConsumptionCategory.veryHigh:
      default:
        return {
          'title': 'Very High Usage Alert',
          'subtitle': 'Potential leak detected or unusually high usage predicted.',
          'icon': Icons.warning_amber,
          'color': Colors.redAccent,
          'explanation': 'A K-Nearest Neighbors (KNN) model running in the cloud analyzed your billing history. Your usage (e.g., > 40 m³) is significantly high. This could indicate a leak. Please inspect your fixtures or report an issue.',
        };
    }
  }

  // --- Helper to show explanation dialog ---
  void _showExplanationDialog(BuildContext context, Map<String, dynamic> mainProps) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF152D4E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: mainProps['color'].withOpacity(0.5), width: 1),
          ),
          icon: Icon(mainProps['icon'], color: mainProps['color'], size: 40),
          title: Text(
            mainProps['title'],
            textAlign: TextAlign.center,
            style: TextStyle(
              color: mainProps['color'],
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            mainProps['explanation'],
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
    final mainProps = _getConsumptionProperties();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: GestureDetector(
        onTap: () => _showExplanationDialog(context, mainProps),
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                mainProps['color'].withAlpha(38),
                mainProps['color'].withAlpha(20),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25.0),
            border: Border.all(color: mainProps['color'].withAlpha(51)),
          ),
          child: Column(
            children: [
              // --- 1. Main KNN Prediction (as header) ---
              Row(
                children: [
                  Icon(mainProps['icon'], color: mainProps['color'], size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mainProps['title'],
                          style: TextStyle(
                            color: mainProps['color'],
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mainProps['subtitle'],
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.info_outline, color: Colors.white.withAlpha(80), size: 20),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),

              // --- 2. Naive Bayes ---
              if (resolutionTimeCategory != null)
                _buildSubPredictionRow(
                  category: resolutionTimeCategory!,
                  icon: _getBayesIcon(resolutionTimeCategory!),
                  color: _getBayesColor(resolutionTimeCategory!),
                  title: 'Complaint Resolution: ${_getBayesTitle(resolutionTimeCategory!)}',
                ),

              // --- 3. Decision Tree ---
              if (leakageProbabilityCategory != null)
                _buildSubPredictionRow(
                  category: leakageProbabilityCategory!,
                  icon: _getTreeIcon(leakageProbabilityCategory!),
                  color: _getTreeColor(leakageProbabilityCategory!),
                  title: 'Leakage Probability: ${_getTreeTitle(leakageProbabilityCategory!)}',
                ),

              // --- 4. SVM ---
              if (billingAccuracyCategory != null)
                _buildSubPredictionRow(
                  category: billingAccuracyCategory!,
                  icon: _getSvmIcon(billingAccuracyCategory!),
                  color: _getSvmColor(billingAccuracyCategory!),
                  title: 'Billing Accuracy: ${_getSvmTitle(billingAccuracyCategory!)}',
                ),

              // --- 5. Neural Network ---
              if (peakDemandCategory != null)
                _buildSubPredictionRow(
                  category: peakDemandCategory!,
                  icon: _getNnIcon(peakDemandCategory!),
                  color: _getNnColor(peakDemandCategory!),
                  title: 'Peak Demand: ${_getNnTitle(peakDemandCategory!)}',
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// A small row widget for the sub-predictions
  Widget _buildSubPredictionRow({
    required Enum category,
    required IconData icon,
    required Color color,
    required String title,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- Property Helpers for Sub-Predictions ---

  // Naive Bayes
  String _getBayesTitle(ResolutionTimeCategory cat) {
    switch (cat) {
      case ResolutionTimeCategory.fast: return 'Fast';
      case ResolutionTimeCategory.medium: return 'Medium';
      case ResolutionTimeCategory.slow: return 'Slow';
    }
  }
  IconData _getBayesIcon(ResolutionTimeCategory cat) {
    switch (cat) {
      case ResolutionTimeCategory.fast: return Icons.speed;
      case ResolutionTimeCategory.medium: return Icons.schedule;
      case ResolutionTimeCategory.slow: return Icons.hourglass_bottom;
    }
  }
  Color _getBayesColor(ResolutionTimeCategory cat) {
    switch (cat) {
      case ResolutionTimeCategory.fast: return Colors.greenAccent;
      case ResolutionTimeCategory.medium: return Colors.blueAccent;
      case ResolutionTimeCategory.slow: return Colors.orangeAccent;
    }
  }

  // Decision Tree
  String _getTreeTitle(LeakageProbabilityCategory cat) {
    switch (cat) {
      case LeakageProbabilityCategory.low: return 'Low';
      case LeakageProbabilityCategory.medium: return 'Medium';
      case LeakageProbabilityCategory.high: return 'High';
    }
  }
  IconData _getTreeIcon(LeakageProbabilityCategory cat) {
    switch (cat) {
      case LeakageProbabilityCategory.low: return Icons.shield_outlined;
      case LeakageProbabilityCategory.medium: return Icons.water_drop;
      case LeakageProbabilityCategory.high: return Icons.warning_amber;
    }
  }
  Color _getTreeColor(LeakageProbabilityCategory cat) {
    switch (cat) {
      case LeakageProbabilityCategory.low: return Colors.greenAccent;
      case LeakageProbabilityCategory.medium: return Colors.orangeAccent;
      case LeakageProbabilityCategory.high: return Colors.redAccent;
    }
  }

  // SVM
  String _getSvmTitle(BillingAccuracyCategory cat) {
    switch (cat) {
      case BillingAccuracyCategory.high: return 'High';
      case BillingAccuracyCategory.medium: return 'Medium';
      case BillingAccuracyCategory.low: return 'Anomaly';
    }
  }
  IconData _getSvmIcon(BillingAccuracyCategory cat) {
    switch (cat) {
      case BillingAccuracyCategory.high: return Icons.verified;
      case BillingAccuracyCategory.medium: return Icons.task_alt;
      case BillingAccuracyCategory.low: return Icons.error_outline;
    }
  }
  Color _getSvmColor(BillingAccuracyCategory cat) {
    switch (cat) {
      case BillingAccuracyCategory.high: return Colors.greenAccent;
      case BillingAccuracyCategory.medium: return Colors.blueAccent;
      case BillingAccuracyCategory.low: return Colors.orangeAccent;
    }
  }

  // Neural Network
  String _getNnTitle(PeakDemandCategory cat) {
    switch (cat) {
      case PeakDemandCategory.morning: return 'Morning';
      case PeakDemandCategory.afternoon: return 'Afternoon';
      case PeakDemandCategory.evening: return 'Evening';
    }
  }
  IconData _getNnIcon(PeakDemandCategory cat) {
    switch (cat) {
      case PeakDemandCategory.morning: return Icons.wb_sunny_outlined;
      case PeakDemandCategory.afternoon: return Icons.brightness_5_outlined;
      case PeakDemandCategory.evening: return Icons.brightness_3_outlined;
    }
  }
  Color _getNnColor(PeakDemandCategory cat) {
    switch (cat) {
      case PeakDemandCategory.morning: return Colors.yellowAccent;
      case PeakDemandCategory.afternoon: return Colors.lightBlueAccent;
      case PeakDemandCategory.evening: return Colors.purpleAccent;
    }
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aquasense/models/billing_info.dart';
import 'package:ml_algo/ml_algo.dart';
import 'package:ml_dataframe/ml_dataframe.dart';

// Enum to define our consumption categories
enum ConsumptionCategory {
  efficient,
  average,
  high,
  veryHigh,
}

class MLService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Defines the consumption thresholds (in cubic meters per month)
  static const double _efficientThreshold = 10.0; // e.g., less than 10 m³
  static const double _averageThreshold = 25.0;  // e.g., 10-25 m³
  static const double _highThreshold = 40.0;     // e.g., 25-40 m³
  // Anything above highThreshold is considered 'VeryHigh'

  // Converts a numerical consumption value to a category
  ConsumptionCategory _getCategoryForConsumption(double consumption) {
    if (consumption <= _efficientThreshold) {
      return ConsumptionCategory.efficient;
    } else if (consumption <= _averageThreshold) {
      return ConsumptionCategory.average;
    } else if (consumption <= _highThreshold) {
      return ConsumptionCategory.high;
    } else {
      return ConsumptionCategory.veryHigh;
    }
  }

  // Fetches all necessary data from Firestore for a given ward
  Future<DataFrame?> _fetchAllWardData(String wardId) async {
    final List<List<dynamic>> allDataRows = [];
    final usersSnapshot = await _db.collection('users').where('wardId', isEqualTo: wardId).get();

    for (var userDoc in usersSnapshot.docs) {
      final billingHistorySnapshot = await userDoc.reference.collection('billingHistory').orderBy('date').get();
      if (billingHistorySnapshot.docs.length > 1) {
        final bills = billingHistorySnapshot.docs.map((doc) => BillingInfo.fromFirestore(doc)).toList();
        List<double> monthlyConsumptions = [];
        for (int i = 1; i < bills.length; i++) {
          monthlyConsumptions.add((bills[i].reading - bills[i - 1].reading).toDouble());
        }
        if (monthlyConsumptions.isEmpty) continue;

        final double averageConsumption = monthlyConsumptions.reduce((a, b) => a + b) / monthlyConsumptions.length;

        for (int i = 0; i < monthlyConsumptions.length; i++) {
          allDataRows.add([
            averageConsumption,
            bills[i + 1].date.toDate().month,
            _getCategoryForConsumption(monthlyConsumptions[i]).index,
          ]);
        }
      }
    }

    if (allDataRows.isEmpty) {
      return null;
    }

    // Create a DataFrame with a header and the collected rows
    return DataFrame(
      allDataRows,
      header: ['avg_consumption', 'month', 'category'],
    );
  }

  // The main prediction function
  Future<ConsumptionCategory?> predictConsumptionCategory({
    required String wardId,
    required String userId,
  }) async {
    // 1. Fetch historical data for all users in the ward
    final DataFrame? trainingData = await _fetchAllWardData(wardId);
    if (trainingData == null || trainingData.rows.length < 5) { // Need enough data
      return null;
    }

    // 2. Fetch the target user's data to find their average consumption
    double currentUserAverageConsumption = 0.0;
    final userBillingSnapshot = await _db.collection('users').doc(userId).collection('billingHistory').orderBy('date').get();
    if (userBillingSnapshot.docs.length > 1) {
      final bills = userBillingSnapshot.docs.map((doc) => BillingInfo.fromFirestore(doc)).toList();
      List<double> consumptions = [];
      for (int i = 1; i < bills.length; i++) {
        consumptions.add((bills[i].reading - bills[i - 1].reading).toDouble());
      }
      if (consumptions.isEmpty) return null;
      currentUserAverageConsumption = consumptions.reduce((a, b) => a + b) / consumptions.length;
    } else {
      return null; // Not enough data for the current user
    }

    // 3. Prepare data for the KNN model
    final KnnClassifier classifier = KnnClassifier(
      trainingData,
      'category', // Target column name
      5,          // The value of K
    );

    // 4. Create the prediction point for the next month
    final nextMonth = (DateTime.now().month % 12) + 1;
    final predictionPoint = DataFrame.fromSeries([
      Series('avg_consumption', [currentUserAverageConsumption]),
      Series('month', [nextMonth]),
    ]);

    // 5. Make the prediction
    final prediction = classifier.predict(predictionPoint);
    final predictedCategoryIndex = prediction.rows.first.first as int;

    return ConsumptionCategory.values[predictedCategoryIndex];
  }
}
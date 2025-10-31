import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// Enum for the existing Consumption Prediction (KNN)
enum ConsumptionCategory {
  efficient,
  average,
  high,
  veryHigh,
}

class MLService {
  // This is your existing function for the KNN model.
  // It is NOT used by the new cards.
  Future<ConsumptionCategory?> predictConsumptionCategory({
    required String wardId,
    required String userId,
    required String modelName,
  }) async {
    debugPrint("MLService: Calling predictConsumption Cloud Function for user $userId in ward $wardId using model: $modelName");

    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint("MLService: No user logged in. Aborting function call.");
        return null;
      }
      String? idToken = await currentUser.getIdToken(true);
      if (idToken == null) {
        debugPrint("MLService: Failed to get refreshed ID token. Aborting function call.");
        return null;
      }
      debugPrint("MLService: Successfully obtained refreshed ID token.");
    } catch (e) {
      debugPrint("MLService: Error refreshing ID token: $e. Aborting function call.");
      return null;
    }

    try {
      String? appCheckToken = await FirebaseAppCheck.instance.getToken(true);
      if (appCheckToken == null) {
        debugPrint("MLService: Failed to get App Check token. Aborting function call.");
        return null;
      }
      debugPrint("MLService: Successfully obtained App Check token.");
    } catch (e) {
      debugPrint("MLService: Error getting App Check token: $e. Aborting function call.");
      return null;
    }

    FirebaseFunctions functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    final HttpsCallable callable = functions.httpsCallable('predictConsumption');

    try {
      final result = await callable.call<Map<String, dynamic>>({
        'userId': userId,
        'wardId': wardId,
        'modelName': modelName,
      });

      final String? categoryName = result.data['category'] as String?;
      debugPrint("MLService: Cloud Function returned category name: $categoryName");

      if (categoryName != null) {
        try {
          return ConsumptionCategory.values.firstWhere(
                (e) => e.toString().split('.').last == categoryName,
          );
        } catch (e) {
          debugPrint("MLService: Error - Could not map category name '$categoryName' to enum: $e");
          return null;
        }
      } else {
        debugPrint("MLService: Cloud Function returned null category.");
        return null;
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint("MLService: Cloud Functions Exception: ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      debugPrint("MLService: Generic Error calling Cloud Function: $e");
      return null;
    }
  }
}

// --- NEW ENUMS FOR NEW PREDICTION CARDS ---

// 2. For Naive Bayes: Complaint Resolution Time
enum ResolutionTimeCategory {
  fast,
  medium,
  slow,
}

// 3. For Decision Tree: Leakage Probability
enum LeakageProbabilityCategory {
  low,
  medium,
  high,
}

// 4. For SVM: Billing Accuracy
enum BillingAccuracyCategory {
  high,
  medium,
  low,
}

// 5. For Neural Network: Peak Demand Time
enum PeakDemandCategory {
  morning,
  afternoon,
  evening,
}
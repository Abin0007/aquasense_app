import 'package:cloud_firestore/cloud_firestore.dart'; // Keep if needed elsewhere
import 'package:cloud_functions/cloud_functions.dart'; // Import Cloud Functions
import 'package:flutter/foundation.dart';

// Enum to define our consumption categories (KEEP THIS)
enum ConsumptionCategory {
  efficient,
  average,
  high,
  veryHigh,
}

class MLService {
  // --- REMOVED Firestore instance and threshold constants if only used for prediction ---

  // --- REMOVED _getCategoryForConsumption and _fetchAllWardData methods ---


  // The main prediction function - NOW CALLS CLOUD FUNCTION
  Future<ConsumptionCategory?> predictConsumptionCategory({
    required String wardId,
    required String userId,
  }) async {
    // --- DEBUG PRINT ADDED ---
    debugPrint("MLService: Calling predictConsumption Cloud Function for user $userId in ward $wardId");
    // -------------------------

    // Get instance of Cloud Functions
    FirebaseFunctions functions = FirebaseFunctions.instance;
    // Optional: Use emulator during development
    // functions.useFunctionsEmulator('localhost', 5001);

    // Prepare the data to send to the function
    final HttpsCallable callable = functions.httpsCallable('predictConsumption');

    try {
      final result = await callable.call<Map<String, dynamic>>({
        'userId': userId,
        'wardId': wardId,
      });

      final String? categoryName = result.data['category'] as String?;
      // --- DEBUG PRINT ADDED ---
      debugPrint("MLService: Cloud Function returned category name: $categoryName");
      // -------------------------

      if (categoryName != null) {
        // Convert the string name back to the enum
        try {
          // Use try-firstWhere to handle potential mismatch gracefully
          return ConsumptionCategory.values.firstWhere(
                (e) => e.toString().split('.').last == categoryName,
          );
        } catch (e) {
          // --- DEBUG PRINT ADDED ---
          debugPrint("MLService: Error - Could not map category name '$categoryName' to enum: $e");
          // --- FIX: Explicitly return null here ---
          return null;
        }

      } else {
        // --- DEBUG PRINT ADDED ---
        debugPrint("MLService: Cloud Function returned null category.");
        // -------------------------
        return null; // Prediction failed or insufficient data
      }
    } on FirebaseFunctionsException catch (e) {
      // --- DEBUG PRINT ADDED ---
      debugPrint("MLService: Cloud Functions Exception: ${e.code} - ${e.message}");
      // -------------------------
      // Handle specific errors (e.g., 'unauthenticated', 'internal')
      return null;
    } catch (e) {
      // --- DEBUG PRINT ADDED ---
      debugPrint("MLService: Generic Error calling Cloud Function: $e");
      // -------------------------
      return null;
    }
  }
}
import 'package:cloud_firestore/cloud_firestore.dart'; // Keep if needed elsewhere
import 'package:cloud_functions/cloud_functions.dart'; // Import Cloud Functions
import 'package:firebase_app_check/firebase_app_check.dart'; // Import App Check
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:flutter/foundation.dart';

// Enum to define our consumption categories (KEEP THIS)
enum ConsumptionCategory {
  efficient,
  average,
  high,
  veryHigh,
}

class MLService {

  // The main prediction function - NOW CALLS CLOUD FUNCTION
  Future<ConsumptionCategory?> predictConsumptionCategory({
    required String wardId,
    required String userId,
  }) async {
    debugPrint("MLService: Calling predictConsumption Cloud Function for user $userId in ward $wardId");

    // --- ADDED: Force Firebase Auth ID token refresh ---
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint("MLService: No user logged in. Aborting function call.");
        return null; // Don't proceed if no user
      }
      // Force refresh the ID token
      String? idToken = await currentUser.getIdToken(true); // Pass true to force refresh
      if (idToken == null) {
        debugPrint("MLService: Failed to get refreshed ID token. Aborting function call.");
        return null;
      }
      debugPrint("MLService: Successfully obtained refreshed ID token.");
    } catch (e) {
      debugPrint("MLService: Error refreshing ID token: $e. Aborting function call.");
      return null;
    }
    // --- END Auth Token Refresh ---


    // --- Get App Check token (keep this) ---
    try {
      String? appCheckToken = await FirebaseAppCheck.instance.getToken(true); // Force refresh App Check token too
      if (appCheckToken == null) {
        debugPrint("MLService: Failed to get App Check token. Aborting function call.");
        return null;
      }
      debugPrint("MLService: Successfully obtained App Check token.");
    } catch (e) {
      debugPrint("MLService: Error getting App Check token: $e. Aborting function call.");
      return null;
    }
    // --- End App Check Token ---


    // Get instance of Cloud Functions and EXPLICITLY set region
    FirebaseFunctions functions = FirebaseFunctions.instanceFor(region: 'us-central1'); // Specify region
    // Optional: Use emulator during development
    // functions.useFunctionsEmulator('localhost', 5001);

    // Prepare the data to send to the function
    final HttpsCallable callable = functions.httpsCallable('predictConsumption');

    try {
      // Make the call
      final result = await callable.call<Map<String, dynamic>>({
        'userId': userId,
        'wardId': wardId,
      });

      final String? categoryName = result.data['category'] as String?;
      debugPrint("MLService: Cloud Function returned category name: $categoryName");

      if (categoryName != null) {
        // Convert the string name back to the enum
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
        return null; // Prediction failed or insufficient data
      }
    } on FirebaseFunctionsException catch (e) {
      // Log specific Cloud Functions errors
      debugPrint("MLService: Cloud Functions Exception: ${e.code} - ${e.message}");
      return null; // Return null on error
    } catch (e) {
      debugPrint("MLService: Generic Error calling Cloud Function: $e");
      return null;
    }
  }
}
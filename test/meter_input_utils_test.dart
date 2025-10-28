// test/meter_input_utils_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Adjust import path as needed
import 'package:aquasense/models/billing_info.dart';

// Extracted logic for testing
double getAverageConsumption(List<BillingInfo> billingHistory) {
  if (billingHistory.length < 2) return 0.0;

  // Sort history oldest to newest
  final sortedHistory = List<BillingInfo>.from(billingHistory)
    ..sort((a, b) => a.date.compareTo(b.date));

  List<double> consumptionData = [];
  for (int i = 1; i < sortedHistory.length; i++) {
    // Basic check for roughly monthly interval (can be refined in real tests)
    final daysDiff = sortedHistory[i].date.toDate().difference(sortedHistory[i-1].date.toDate()).inDays;
    // Count intervals between 21 and 39 days as roughly monthly
    if (daysDiff > 20 && daysDiff < 40) {
      final consumption = sortedHistory[i].reading - sortedHistory[i - 1].reading;
      if (consumption >= 0) { // Ignore negative readings
        consumptionData.add(consumption.toDouble());
      }
    }
  }
  if (consumptionData.isEmpty) return 0.0;
  return consumptionData.reduce((a, b) => a + b) / consumptionData.length;
}


void main() {
  group('MeterInputWidget Utils - getAverageConsumption', () {

    // Helper to create BillingInfo with a specific date offset
    BillingInfo createBill(int daysAgo, int reading) {
      return BillingInfo(
        id: 'bill_$daysAgo',
        date: Timestamp.fromDate(DateTime.now().subtract(Duration(days: daysAgo))),
        amount: 100, // Amount doesn't affect consumption calc
        reading: reading,
        status: 'Paid', // Status doesn't affect consumption calc
      );
    }

    test('should return 0.0 if history has less than 2 bills', () {
      expect(getAverageConsumption([]), 0.0);
      expect(getAverageConsumption([createBill(30, 100)]), 0.0);
    });

    test('should calculate average consumption correctly for monthly bills', () {
      final history = [
        createBill(90, 100), // Start
        createBill(60, 120), // Consumption: 20 (30 day interval)
        createBill(30, 150), // Consumption: 30 (30 day interval)
        createBill(0, 190),  // Consumption: 40 (30 day interval)
      ];
      // Average = (20 + 30 + 40) / 3 = 90 / 3 = 30
      expect(getAverageConsumption(history), closeTo(30.0, 0.01));
    });

    test('should ignore non-monthly intervals (e.g., bills too close)', () {
      final history = [
        createBill(60, 100),
        createBill(55, 110), // Only 5 days diff - ignored
        createBill(30, 130), // Consumption: 20 (25 day interval from bill @ 55 days)
        createBill(0, 170),  // Consumption: 40 (30 day interval from bill @ 30 days)
      ];
      // Average = (20 + 40) / 2 = 30
      // *** CORRECTED EXPECTATION ***
      expect(getAverageConsumption(history), closeTo(30.0, 0.01));
    });

    test('should ignore negative consumption readings', () {
      final history = [
        createBill(90, 100),
        createBill(60, 80),  // Consumption: -20 (ignored, 30 day interval)
        createBill(30, 110), // Consumption: 30 (30 day interval from bill @ 60 days)
        createBill(0, 150),  // Consumption: 40 (30 day interval from bill @ 30 days)
      ];
      // Average = (30 + 40) / 2 = 35
      expect(getAverageConsumption(history), closeTo(35.0, 0.01));
    });

    test('should return 0.0 if no valid monthly intervals found', () {
      final history = [
        createBill(10, 100),
        createBill(5, 110), // Too close
        createBill(0, 120),  // Too close
      ];
      expect(getAverageConsumption(history), 0.0);
    });

    // Test case with slightly varied intervals still within range
    test('should handle varied intervals within the 21-39 day range', () {
      final history = [
        createBill(100, 200),
        createBill(75, 225), // Interval: 25 days, Consumption: 25
        createBill(40, 260), // Interval: 35 days, Consumption: 35
        createBill(10, 300), // Interval: 30 days, Consumption: 40
      ];
      // Average = (25 + 35 + 40) / 3 = 100 / 3 = 33.33...
      expect(getAverageConsumption(history), closeTo(33.33, 0.01));
    });


  });
}
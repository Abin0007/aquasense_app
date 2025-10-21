import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aquasense/models/billing_info.dart';
import 'package:aquasense/models/complaint_model.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  /// Returns a real-time stream of the user's entire billing history, sorted by date.
  Stream<List<BillingInfo>> getBillingHistoryStream() {
    if (_userId == null) {
      // Return an empty stream if the user is not logged in.
      return Stream.value([]);
    }
    return _db
        .collection('users')
        .doc(_userId)
        .collection('billingHistory')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => BillingInfo.fromFirestore(doc)).toList());
  }

  /// Returns a real-time stream of all unpaid bills for the current user.
  /// This is used by the home screen card to calculate the total amount due.
  Stream<List<BillingInfo>> getAllUnpaidBillsStream() {
    if (_userId == null) {
      return Stream.value([]);
    }
    return _db
        .collection('users')
        .doc(_userId)
        .collection('billingHistory')
        .where('status', isEqualTo: 'Due')
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => BillingInfo.fromFirestore(doc)).toList());
  }

  /// Updates a bill's status to 'Paid' and records the payment ID and timestamp.
  Future<void> updateBillStatus(String billId, String paymentId) async {
    if (_userId == null) {
      throw Exception("User not logged in");
    }
    try {
      await _db
          .collection('users')
          .doc(_userId)
          .collection('billingHistory')
          .doc(billId)
          .update({
        'status': 'Paid',
        'paymentId': paymentId,
        'paidAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error updating bill status: $e");
      throw Exception("Failed to update bill status");
    }
  }

  /// Submits a new complaint to the central 'complaints' collection.
  Future<void> submitComplaint(Complaint complaint) async {
    if (_userId == null) {
      throw Exception("User not logged in");
    }
    try {
      await _db.collection('complaints').add(complaint.toMap());
    } catch (e) {
      debugPrint("Error submitting complaint: $e");
      throw Exception("Failed to submit complaint. Please try again.");
    }
  }
}


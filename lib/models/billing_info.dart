import 'package:cloud_firestore/cloud_firestore.dart';

class BillingInfo {
  final String id;
  final Timestamp date;
  final double amount;
  final int reading;
  final String status; // e.g., "Paid", "Due"
  final Timestamp? paidAt;
  final String? paymentId;
  final double? fineAmount; // NEW FIELD: To store the calculated fine

  BillingInfo({
    required this.id,
    required this.date,
    required this.amount,
    required this.reading,
    required this.status,
    this.paidAt,
    this.paymentId,
    this.fineAmount, // NEW FIELD
  });

  factory BillingInfo.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return BillingInfo(
      id: doc.id,
      date: data['date'] ?? Timestamp.now(),
      amount: (data['amount'] ?? 0.0).toDouble(),
      reading: data['reading'] ?? 0,
      status: data['status'] ?? 'Due',
      paidAt: data['paidAt'],
      paymentId: data['paymentId'],
      fineAmount: (data['fineAmount'] as num?)?.toDouble(), // NEW FIELD
    );
  }

  // Helper method to calculate the fine for a due bill
  double get currentFine {
    if (status != 'Due') return 0.0;

    // Due period is 10 days from the bill generation date
    final dueDate = date.toDate().add(const Duration(days: 10));
    final today = DateTime.now();

    if (today.isAfter(dueDate)) {
      final daysLate = today.difference(dueDate).inDays;
      return daysLate.toDouble(); // 1 rupee per day fine
    }
    return 0.0;
  }

  // Helper to check if payment was made late
  bool get wasPaidLate {
    if (paidAt == null) return false;
    final dueDate = date.toDate().add(const Duration(days: 10));
    return paidAt!.toDate().isAfter(dueDate);
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

class CashCollection {
  final String id;
  final double amount;
  final Timestamp collectedAt;
  final String citizenId;
  final String supervisorId;
  final String status;

  CashCollection.fromDoc(DocumentSnapshot doc)
      : id = doc.id,
        amount = (doc.get('amount') as num).toDouble(),
        collectedAt = doc.get('collectedAt') as Timestamp,
        citizenId = doc.get('citizenId') as String,
        supervisorId = doc.get('supervisorId') as String,
        status = doc.get('status') as String;
}
import 'package:cloud_firestore/cloud_firestore.dart';

class WardPricing {
  final String wardId;
  final double pricePerUnit;

  WardPricing({
    required this.wardId,
    required this.pricePerUnit,
  });

  factory WardPricing.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WardPricing(
      wardId: doc.id,
      pricePerUnit: (data['pricePerUnit'] as num?)?.toDouble() ?? 10.0,
    );
  }
}


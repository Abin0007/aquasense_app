import 'package:cloud_firestore/cloud_firestore.dart';

class WaterTank {
  final String id;
  final String tankName;
  final int level;
  final Timestamp lastUpdated;

  WaterTank({
    required this.id,
    required this.tankName,
    required this.level,
    required this.lastUpdated,
  });

  factory WaterTank.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WaterTank(
      id: doc.id,
      tankName: data['tankName'] ?? 'Unnamed Tank',
      level: (data['level'] ?? 0).toInt(),
      lastUpdated: data['lastUpdated'] ?? Timestamp.now(),
    );
  }
}


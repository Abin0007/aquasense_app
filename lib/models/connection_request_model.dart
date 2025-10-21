import 'package:cloud_firestore/cloud_firestore.dart';

class StatusUpdate {
  final String status;
  final String description;
  final Timestamp updatedAt;

  StatusUpdate({
    required this.status,
    required this.description,
    required this.updatedAt,
  });

  factory StatusUpdate.fromMap(Map<String, dynamic> map) {
    return StatusUpdate(
      status: map['status'] ?? 'Unknown',
      description: map['description'] ?? '',
      updatedAt: map['updatedAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'description': description,
      'updatedAt': updatedAt,
    };
  }
}

class ConnectionRequest {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String address;
  final String pincode;
  final double? latitude;
  final double? longitude;
  final String residentialProofUrl;
  final Timestamp appliedAt;
  final String currentStatus;
  final List<StatusUpdate> statusHistory;
  final String? rejectionReason;
  final String? finalConnectionImageUrl;
  final GeoPoint? finalConnectionLocation;
  final Timestamp? connectionCreatedAt;
  final String wardId; // <-- ADDED THIS FIELD

  ConnectionRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.address,
    required this.pincode,
    this.latitude,
    this.longitude,
    required this.residentialProofUrl,
    required this.appliedAt,
    required this.currentStatus,
    required this.statusHistory,
    this.rejectionReason,
    this.finalConnectionImageUrl,
    this.finalConnectionLocation,
    this.connectionCreatedAt,
    required this.wardId, // <-- ADDED TO CONSTRUCTOR
  });

  factory ConnectionRequest.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    final historyData = data['statusHistory'] as List<dynamic>? ?? [];
    final statusHistory = historyData
        .map((item) => StatusUpdate.fromMap(item as Map<String, dynamic>))
        .toList();

    return ConnectionRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'N/A',
      userEmail: data['userEmail'] ?? 'N/A',
      address: data['address'] ?? '',
      pincode: data['pincode'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      residentialProofUrl: data['residentialProofUrl'] ?? '',
      appliedAt: data['appliedAt'] ?? Timestamp.now(),
      currentStatus: data['currentStatus'] ?? 'Unknown',
      statusHistory: statusHistory,
      rejectionReason: data['rejectionReason'],
      finalConnectionImageUrl: data['finalConnectionImageUrl'],
      finalConnectionLocation: data['finalConnectionLocation'],
      connectionCreatedAt: data['connectionCreatedAt'],
      wardId: data['wardId'] ?? '', // <-- READ THE FIELD FROM FIRESTORE
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

class Complaint {
  final String? id;
  final String userId;
  final String type;
  final String description;
  final String? imageUrl;
  final GeoPoint? location;
  final String wardId;
  final Timestamp createdAt;
  final String status;

  Complaint({
    this.id,
    required this.userId,
    required this.type,
    required this.description,
    this.imageUrl,
    this.location,
    required this.wardId,
    required this.createdAt,
    this.status = 'Submitted',
  });

  factory Complaint.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Complaint(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? 'General',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      location: data['location'],
      wardId: data['wardId'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      status: data['status'] ?? 'Submitted',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'description': description,
      'imageUrl': imageUrl,
      'location': location,
      'wardId': wardId,
      'createdAt': createdAt,
      'status': status,
    };
  }
}
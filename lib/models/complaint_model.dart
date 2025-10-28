import 'package:cloud_firestore/cloud_firestore.dart';

// New class for status updates within the complaint
class ComplaintStatusUpdate {
  final String status;
  final Timestamp updatedAt;
  final String? supervisorImageUrl; // URL for supervisor's image for this status
  final String updatedBy; // UID of user who made the update (supervisor/admin)

  ComplaintStatusUpdate({
    required this.status,
    required this.updatedAt,
    this.supervisorImageUrl,
    required this.updatedBy,
  });

  factory ComplaintStatusUpdate.fromMap(Map<String, dynamic> map) {
    return ComplaintStatusUpdate(
      status: map['status'] ?? 'Unknown',
      updatedAt: map['updatedAt'] ?? Timestamp.now(),
      supervisorImageUrl: map['supervisorImageUrl'],
      updatedBy: map['updatedBy'] ?? 'unknown',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'updatedAt': updatedAt,
      'supervisorImageUrl': supervisorImageUrl,
      'updatedBy': updatedBy,
    };
  }
}


class Complaint {
  final String? id;
  final String userId;
  final String type;
  final String description;
  final String? imageUrl; // Citizen's initial image
  final GeoPoint? location;
  final String wardId;
  final Timestamp createdAt;
  final String status; // Current overall status
  final List<ComplaintStatusUpdate> statusHistory; // NEW: History of updates
  final int? citizenRating; // NEW: Rating (1-5) given by citizen

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
    this.statusHistory = const [], // Default to empty list
    this.citizenRating,          // Null initially
  });

  factory Complaint.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Parse status history
    final historyData = data['statusHistory'] as List<dynamic>? ?? [];
    final statusHistory = historyData
        .map((item) => ComplaintStatusUpdate.fromMap(item as Map<String, dynamic>))
        .toList();
    // Sort history by date descending for easier access to latest relevant images later
    statusHistory.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));


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
      statusHistory: statusHistory, // Assign parsed history
      citizenRating: data['citizenRating'], // Assign rating
    );
  }

  Map<String, dynamic> toMap() {
    // Note: When submitting a *new* complaint, statusHistory might be omitted or include the initial 'Submitted' status
    return {
      'userId': userId,
      'type': type,
      'description': description,
      'imageUrl': imageUrl,
      'location': location,
      'wardId': wardId,
      'createdAt': createdAt,
      'status': status,
      // 'statusHistory' is typically updated server-side or via specific update functions
      // 'citizenRating' is updated separately by the citizen
    };
  }

  // Helper to get the latest supervisor image for a specific status
  String? getSupervisorImageForStatus(String targetStatus) {
    return statusHistory
        .firstWhere(
            (update) => update.status == targetStatus && update.supervisorImageUrl != null,
        orElse: () => ComplaintStatusUpdate(status: '', updatedAt: Timestamp(0,0), updatedBy: '') // Return a dummy obj if not found
    )
        .supervisorImageUrl;
  }
}
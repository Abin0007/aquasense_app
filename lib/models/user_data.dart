import 'package:cloud_firestore/cloud_firestore.dart';

class UserData {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String wardId;
  final String? phoneNumber;
  final bool isPhoneVerified;
  final Timestamp createdAt;
  final bool hasActiveConnection;
  final String? profileImageUrl;

  UserData({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.wardId,
    this.phoneNumber,
    this.isPhoneVerified = false,
    required this.createdAt,
    this.hasActiveConnection = false,
    this.profileImageUrl, // ✅ ADDED TO CONSTRUCTOR
  });

  factory UserData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserData(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'citizen',
      wardId: data['wardId'] ?? '',
      phoneNumber: data['phoneNumber'],
      isPhoneVerified: data['isPhoneVerified'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      hasActiveConnection: data['hasActiveConnection'] ?? false,
      profileImageUrl: data['profileImageUrl'], // ✅ READ FROM FIRESTORE
    );
  }
}
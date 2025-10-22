import 'package:aquasense/screens/admin/admin_dashboard.dart'; // Import the new Admin Dashboard
import 'package:aquasense/screens/supervisor/supervisor_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aquasense/screens/dashboard/citizen_dashboard.dart';
import 'package:aquasense/screens/auth/complete_profile_screen.dart';

class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Handle case where user document might not exist yet after social sign-in
        if (!snapshot.hasData || !snapshot.data!.exists) {
          // Check if essential fields like wardId are missing even if doc exists
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          if (data == null || !data.containsKey('wardId') || data['wardId'] == null || !data.containsKey('role') || data['role'] == null ) {
            return const CompleteProfileScreen();
          }
          // If role exists, proceed (though wardId might still be null for admins initially if not set)
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;

        // Redirect to complete profile if essential data is missing (handles edge cases)
        if (data == null || !data.containsKey('role') || data['role'] == null || (!data.containsKey('wardId') && data['role'] != 'admin')) {
          return const CompleteProfileScreen();
        }


        final userRole = data['role'];

        // Check the user's role and navigate accordingly
        if (userRole == 'admin') { // <-- ADDED ADMIN CHECK
          return const AdminDashboard();
        } else if (userRole == 'supervisor') {
          return const SupervisorDashboard();
        } else {
          // Default to citizen dashboard
          return const CitizenDashboard();
        }
      },
    );
  }
}
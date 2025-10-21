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

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const CompleteProfileScreen();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;

        if (data == null || !data.containsKey('wardId')) {
          return const CompleteProfileScreen();
        }

        final userRole = data['role'];

        // Check the user's role and navigate accordingly
        if (userRole == 'supervisor') {
          return const SupervisorDashboard();
        } else {
          // Default to citizen dashboard
          return const CitizenDashboard();
        }
      },
    );
  }
}
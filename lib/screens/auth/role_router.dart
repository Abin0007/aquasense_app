import 'package:aquasense/screens/admin/admin_dashboard.dart';
// *** MODIFICATION: Import the new root screen ***
import 'package:aquasense/screens/supervisor/supervisor_root_screen.dart';
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
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          if (data == null || !data.containsKey('wardId') || data['wardId'] == null || !data.containsKey('role') || data['role'] == null ) {
            return const CompleteProfileScreen();
          }
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;

        if (data == null || !data.containsKey('role') || data['role'] == null || (!data.containsKey('wardId') && data['role'] != 'admin')) {
          return const CompleteProfileScreen();
        }


        final userRole = data['role'];

        if (userRole == 'admin') {
          return const AdminDashboard();
        } else if (userRole == 'supervisor') {
          // *** MODIFICATION: Navigate to SupervisorRootScreen ***
          return const SupervisorRootScreen();
        } else {
          return const CitizenDashboard();
        }
      },
    );
  }
}
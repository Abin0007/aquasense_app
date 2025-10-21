import 'package:aquasense/models/complaint_model.dart';
import 'package:aquasense/screens/complaints/components/complaint_list_tile.dart';
import 'package:aquasense/screens/supervisor/complaint_detail_screen.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ViewComplaintsScreen extends StatefulWidget {
  const ViewComplaintsScreen({super.key});

  @override
  State<ViewComplaintsScreen> createState() => _ViewComplaintsScreenState();
}

class _ViewComplaintsScreenState extends State<ViewComplaintsScreen> {
  Future<String?> _getSupervisorWardId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return userDoc.data()?['wardId'];
  }

  int _getStatusPriority(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return 0;
      case 'in progress':
        return 1;
      case 'resolved':
        return 2;
      default:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Complaints in Your Ward'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: FutureBuilder<String?>(
        future: _getSupervisorWardId(),
        builder: (context, wardSnapshot) {
          if (wardSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!wardSnapshot.hasData || wardSnapshot.data == null) {
            return const Center(
                child: Text("Could not retrieve supervisor details."));
          }

          final supervisorWardId = wardSnapshot.data!;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('complaints')
                .where('wardId', isEqualTo: supervisorWardId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No complaints found in your ward.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                );
              }

              final complaints = snapshot.data!.docs
                  .map((doc) => Complaint.fromFirestore(doc))
                  .toList();

              // Sort complaints by status priority and then by date
              complaints.sort((a, b) {
                final priorityA = _getStatusPriority(a.status);
                final priorityB = _getStatusPriority(b.status);
                if (priorityA != priorityB) {
                  return priorityA.compareTo(priorityB);
                }
                return b.createdAt.compareTo(a.createdAt);
              });

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: complaints.length,
                itemBuilder: (context, index) {
                  final complaint = complaints[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(SlideFadeRoute(
                        page: ComplaintDetailScreen(complaint: complaint),
                      ));
                    },
                    child: ComplaintListTile(
                      complaint: complaint,
                    )
                        .animate()
                        .fadeIn(delay: (100 * index).ms)
                        .slideX(begin: -0.2),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
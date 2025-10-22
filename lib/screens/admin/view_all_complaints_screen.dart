import 'package:aquasense/models/complaint_model.dart';
import 'package:aquasense/screens/complaints/components/complaint_list_tile.dart'; // Reuse the existing tile
import 'package:aquasense/screens/supervisor/complaint_detail_screen.dart'; // Reuse supervisor's detail screen for now
import 'package:aquasense/utils/page_transition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ViewAllComplaintsScreen extends StatefulWidget {
  const ViewAllComplaintsScreen({super.key});

  @override
  State<ViewAllComplaintsScreen> createState() => _ViewAllComplaintsScreenState();
}

class _ViewAllComplaintsScreenState extends State<ViewAllComplaintsScreen> {
  // Sorting priority for status
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
        title: const Text('All System Complaints'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Query all complaints, ordered by creation date
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .orderBy('createdAt', descending: true)
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
                'No complaints found in the system.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          final complaints = snapshot.data!.docs
              .map((doc) => Complaint.fromFirestore(doc))
              .toList();

          // Sort complaints primarily by status priority, then by date
          complaints.sort((a, b) {
            final priorityA = _getStatusPriority(a.status);
            final priorityB = _getStatusPriority(b.status);
            if (priorityA != priorityB) {
              return priorityA.compareTo(priorityB);
            }
            // For same status, newest first is already handled by Firestore query order
            return b.createdAt.compareTo(a.createdAt);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: complaints.length,
            itemBuilder: (context, index) {
              final complaint = complaints[index];
              // Admins likely need the same detail view as supervisors to update status etc.
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(SlideFadeRoute(
                    page: ComplaintDetailScreen(complaint: complaint),
                  ));
                },
                // Reuse the existing ComplaintListTile
                child: ComplaintListTile(
                  complaint: complaint,
                  // Admins might not delete complaints directly, supervisors handle resolution
                  // onDelete: () => _deleteComplaint(context, complaint.id!), // Decide if admins need delete
                )
                    .animate()
                    .fadeIn(delay: (50 * index).ms)
                    .slideX(begin: -0.1),
              );
            },
          );
        },
      ),
    );
  }

// Optional: Add delete function if admins should be able to delete complaints
/*
   Future<void> _deleteComplaint(BuildContext context, String complaintId) async {
     // Implement deletion logic similar to ManageAnnouncementsScreen if needed
   }
   */
}
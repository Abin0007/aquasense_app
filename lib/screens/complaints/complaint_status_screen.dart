import 'package:aquasense/models/complaint_model.dart';
import 'package:aquasense/screens/complaints/components/complaint_list_tile.dart';
import 'package:aquasense/screens/complaints/complaint_detail_screen_citizen.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ComplaintStatusScreen extends StatelessWidget {
  const ComplaintStatusScreen({super.key});

  int _getStatusPriority(String status) {
    switch (status.toLowerCase()) {
      case 'submitted': return 0;
      case 'in progress': return 1;
      case 'resolved': return 2;
      default: return 3;
    }
  }

  // --- NEW DELETE FUNCTION ---
  Future<void> _deleteComplaint(BuildContext context, String complaintId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    bool? confirmDelete = await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        title: const Text('Delete Complaint?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to permanently delete this complaint?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance.collection('complaints').doc(complaintId).delete();
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Complaint deleted successfully.')),
        );
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to delete complaint: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(
          child: Text("You need to be logged in to view your complaints."),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              backgroundColor: Colors.transparent,
              title: Text('My Complaints'),
              pinned: true,
            ),
            SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('complaints')
                    .where('userId', isEqualTo: userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red))));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Padding(padding: EdgeInsets.all(48.0), child: Text('You have not submitted any complaints.', style: TextStyle(color: Colors.white70))));
                  }

                  final complaints = snapshot.data!.docs
                      .map((doc) => Complaint.fromFirestore(doc))
                      .toList();

                  complaints.sort((a, b) {
                    final priorityA = _getStatusPriority(a.status);
                    final priorityB = _getStatusPriority(b.status);
                    if (priorityA != priorityB) {
                      return priorityA.compareTo(priorityB);
                    }
                    return b.createdAt.compareTo(a.createdAt);
                  });

                  return ListView.builder(
                    itemCount: complaints.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final complaint = complaints[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(SlideFadeRoute(
                            page: ComplaintDetailScreenCitizen(complaint: complaint),
                          ));
                        },
                        child: ComplaintListTile(
                          complaint: complaint,
                          // --- PASSING THE DELETE FUNCTION ---
                          onDelete: () => _deleteComplaint(context, complaint.id!),
                        )
                            .animate()
                            .fadeIn(delay: (100 * index).ms)
                            .slideX(begin: -0.2),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

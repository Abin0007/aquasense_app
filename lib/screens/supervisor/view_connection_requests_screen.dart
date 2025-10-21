import 'package:aquasense/models/connection_request_model.dart';
import 'package:aquasense/screens/supervisor/connection_request_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class ViewConnectionRequestsScreen extends StatefulWidget {
  const ViewConnectionRequestsScreen({super.key});

  @override
  State<ViewConnectionRequestsScreen> createState() =>
      _ViewConnectionRequestsScreenState();
}

class _ViewConnectionRequestsScreenState
    extends State<ViewConnectionRequestsScreen> {
  Future<String?> _getSupervisorWardId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return userDoc.data()?['wardId'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('New Connection Requests'),
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
                .collection('connection_requests')
                .where('wardId', isEqualTo: supervisorWardId)
                .where('currentStatus', isNotEqualTo: 'Completed')
                .orderBy('currentStatus')
                .orderBy('appliedAt', descending: true)
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
                    'No pending connection requests in your ward.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                );
              }

              final requests = snapshot.data!.docs
                  .map((doc) => ConnectionRequest.fromFirestore(doc))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return Card(
                    color: Colors.white.withAlpha(20),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(request.userName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Applied on ${DateFormat('d MMM yyyy').format(request.appliedAt.toDate())}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: Text(
                        request.currentStatus,
                        style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                ConnectionRequestDetailScreen(request: request),
                          ),
                        );
                      },
                    ),
                  ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: -0.2);
                },
              );
            },
          );
        },
      ),
    );
  }
}
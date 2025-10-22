import 'package:aquasense/models/user_data.dart'; // Import UserData
import 'package:aquasense/screens/announcements/components/announcement_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnnouncementsScreen extends StatefulWidget {
  final UserData userData; // Receive user data

  const AnnouncementsScreen({super.key, required this.userData});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {

  @override
  void initState() {
    super.initState();
    _markAnnouncementsAsRead(); // Mark as read when screen opens
  }

  // --- Function to update the last read timestamp ---
  Future<void> _markAnnouncementsAsRead() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        // Find the latest announcement timestamp relevant to this user
        // *** Fetch the most recent relevant announcement to set the timestamp ***
        Query query = FirebaseFirestore.instance.collection('announcements');
        // Apply the SAME filtering logic used in build() to find the latest *relevant* timestamp
        if (widget.userData.role != 'admin' && widget.userData.wardId.isNotEmpty) {
          // For non-admins, consider both global (null) and their specific ward
          // We need to fetch the latest from either category they can see.
          // Firestore doesn't easily support OR on the same field with null/value.
          // Fetching latest global and latest ward separately might be needed for perfect accuracy,
          // but for simplicity, we'll fetch the absolute latest and update the timestamp.
          // This means the indicator might clear even if the latest wasn't for their ward,
          // which is often acceptable UX.
          // If strict per-ward accuracy is needed, more complex timestamp logic is required.
        }
        query = query.orderBy('createdAt', descending: true).limit(1);

        final latestAnnouncementSnapshot = await query.get();
        Timestamp? latestTimestamp;

        if (latestAnnouncementSnapshot.docs.isNotEmpty) {
          final data = latestAnnouncementSnapshot.docs.first.data() as Map<String, dynamic>?;
          latestTimestamp = data?['createdAt'] as Timestamp?;
        }

        // Only update if there was an announcement to read
        if (latestTimestamp != null) {
          await FirebaseFirestore.instance.collection('users').doc(userId).update({
            // Set timestamp slightly ahead to avoid race conditions with stream
            'lastReadAnnouncementsTimestamp': Timestamp(latestTimestamp.seconds + 1, 0),
          });
          debugPrint("Updated lastReadAnnouncementsTimestamp for user $userId to ${latestTimestamp.toDate().add(const Duration(seconds: 1))}");
        } else {
          // If no announcements ever, set it to now so indicator doesn't show for empty list
          // Check if timestamp already exists before overwriting
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          final userData = userDoc.data();
          if (userData != null && !userData.containsKey('lastReadAnnouncementsTimestamp')) {
            await FirebaseFirestore.instance.collection('users').doc(userId).update({
              'lastReadAnnouncementsTimestamp': Timestamp.now(),
            });
            debugPrint("Set initial lastReadAnnouncementsTimestamp for user $userId");
          }
        }


      } catch (e) {
        debugPrint("Error updating lastReadAnnouncementsTimestamp: $e");
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // --- *** CORRECTED QUERY LOGIC *** ---
    Query query = FirebaseFirestore.instance.collection('announcements');

    // Admins see all announcements, ordered by date.
    if (widget.userData.role == 'admin') {
      query = query.orderBy('createdAt', descending: true);
    }
    // Citizens and Supervisors see global announcements (wardId == null)
    // AND announcements specific to their wardId.
    // Since Firestore doesn't easily support OR on the same field like this,
    // we query for *either* null OR the specific ward ID using separate streams
    // and merge them client-side or restructure the data.
    // FOR NOW: Querying everything and filtering client-side (less efficient but works).
    // A better long-term solution involves data restructuring or stream merging.
    else if (widget.userData.wardId.isNotEmpty) {
      // Fetch all, filter later
      query = query.orderBy('createdAt', descending: true);
    } else {
      // User has no ward ID (should ideally not happen for citizen/supervisor after profile completion)
      // Fetch only global announcements
      query = query.where('wardId', isEqualTo: null).orderBy('createdAt', descending: true);
    }
    // --- *** END OF CORRECTION *** ---


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
              expandedHeight: 120.0,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text('Announcements', style: TextStyle(fontWeight: FontWeight.bold)),
                centerTitle: true, // Center title
              ),
            ),
            SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot>(
                stream: query.snapshots(), // Use the constructed query
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(color: Colors.cyanAccent),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Something went wrong: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent))); // Show error
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48.0),
                        child: Text(
                          'No relevant announcements at the moment.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                    );
                  }

                  // --- Client-side filtering if not admin ---
                  List<QueryDocumentSnapshot> announcements = snapshot.data!.docs;
                  if (widget.userData.role != 'admin' && widget.userData.wardId.isNotEmpty) {
                    announcements = announcements.where((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final wardId = data['wardId'] as String?;
                      return wardId == null || wardId == widget.userData.wardId;
                    }).toList();
                  }
                  if (announcements.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48.0),
                        child: Text(
                          'No relevant announcements at the moment.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                    );
                  }
                  // --- End client-side filtering ---


                  return ListView.builder(
                    itemCount: announcements.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    itemBuilder: (context, index) {
                      final doc = announcements[index];
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final createdBy = data['createdBy'] as String?;
                      // Determine if it's a supervisor post based on whether createdBy matches current user if they are a supervisor
                      final bool isPostOwnerSupervisor = widget.userData.role == 'supervisor' && createdBy == widget.userData.uid;
                      // Determine if the post itself was made by *any* supervisor (requires fetching creator's role - skipped for simplicity, assuming non-admin creator is supervisor)
                      final bool isSupervisorPostGeneral = createdBy != null && !createdBy.contains('admin'); // Heuristic


                      final bool canDelete = widget.userData.role == 'admin' || (widget.userData.role == 'supervisor' && createdBy == widget.userData.uid);

                      // --- Pass creator info and delete callback to card ---
                      return AnnouncementCard(
                        doc: doc,
                        showCreator: true, // Show creator info for clarity
                        isSupervisorPost: isSupervisorPostGeneral, // Pass flag indicating if it was likely a supervisor post
                        onDelete: canDelete ? () => _deleteAnnouncement(context, doc.id) : null,
                      )
                          .animate()
                          .fadeIn(delay: (100 * index).ms, duration: 400.ms)
                          .slideY(begin: 0.5, curve: Curves.easeOut);
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- Delete function (needed if showing delete button here) ---
  Future<void> _deleteAnnouncement(BuildContext context, String docId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    bool? confirmDelete = await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        title: const Text('Delete Announcement?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to permanently delete this announcement?',
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
        await FirebaseFirestore.instance.collection('announcements').doc(docId).delete();
        if (!mounted) return; // Check mounted before showing snackbar
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Announcement deleted successfully.')),
        );
      } catch (e) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to delete announcement: $e')),
        );
      }
    }
  }

}
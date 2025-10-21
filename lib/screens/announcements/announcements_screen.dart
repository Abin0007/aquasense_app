import 'package:aquasense/screens/announcements/components/announcement_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              ),
            ),
            SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('announcements')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
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
                    return const Center(child: Text('Something went wrong.', style: TextStyle(color: Colors.redAccent)));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48.0),
                        child: Text(
                          'No announcements at the moment.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                    );
                  }

                  final announcements = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: announcements.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    itemBuilder: (context, index) {
                      return AnnouncementCard(doc: announcements[index])
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
}
import 'package:aquasense/screens/announcements/components/announcement_card.dart'; // Reuse existing card
import 'package:aquasense/widgets/custom_input.dart'; // Reuse custom input
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ManageAnnouncementsScreen extends StatefulWidget {
  const ManageAnnouncementsScreen({super.key});

  @override
  State<ManageAnnouncementsScreen> createState() =>
      _ManageAnnouncementsScreenState();
}

class _ManageAnnouncementsScreenState extends State<ManageAnnouncementsScreen> with TickerProviderStateMixin{ // Added TickerProviderStateMixin
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  late AnimationController _glowController; // Animation controller for CustomInput

  @override
  void initState() {
    super.initState();
    // Initialize AnimationController for CustomInput glow effect
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }


  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _glowController.dispose(); // Dispose the controller
    super.dispose();
  }

  Future<void> _postAnnouncement() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      _titleController.clear();
      _messageController.clear();
      _formKey.currentState?.reset(); // Reset form state
      FocusScope.of(context).unfocus(); // Dismiss keyboard
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Announcement posted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to post announcement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if(mounted){
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteAnnouncement(String docId) async {
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
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Announcement deleted successfully.')),
        );
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to delete announcement: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Manage Announcements'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap outside
        child: Column(
          children: [
            // --- Form Section ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomInput(
                      controller: _titleController,
                      hintText: 'Announcement Title',
                      icon: Icons.title,
                      glowAnimation: _glowController, // Pass the animation controller
                      validator: (value) =>
                      value!.trim().isEmpty ? 'Title cannot be empty.' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomInput(
                      controller: _messageController,
                      hintText: 'Announcement Message',
                      icon: Icons.message_outlined,
                      keyboardType: TextInputType.multiline, // Allow multiline input
                      glowAnimation: _glowController, // Pass the animation controller
                      validator: (value) =>
                      value!.trim().isEmpty ? 'Message cannot be empty.' : null,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _postAnnouncement,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                          : const Text('Post Announcement',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            // --- List Section ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('announcements')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Error loading announcements.',
                            style: TextStyle(color: Colors.redAccent)));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('No announcements posted yet.',
                            style: TextStyle(color: Colors.white70)));
                  }

                  final announcements = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: announcements.length,
                    itemBuilder: (context, index) {
                      final doc = announcements[index];
                      // Wrap AnnouncementCard with Dismissible or add an IconButton
                      return Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0), // Add padding for the card itself
                              child: AnnouncementCard(doc: doc),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => _deleteAnnouncement(doc.id),
                                tooltip: 'Delete Announcement',
                                style: IconButton.styleFrom(
                                    backgroundColor: Colors.black.withOpacity(0.4)
                                ),
                              ),
                            ),
                          ]
                      ).animate().fadeIn(delay: (50 * index).ms);
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
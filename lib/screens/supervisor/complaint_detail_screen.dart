import 'package:aquasense/models/complaint_model.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final Complaint complaint;
  const ComplaintDetailScreen({super.key, required this.complaint});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  late Future<UserData?> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _fetchUserData();
  }

  Future<UserData?> _fetchUserData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.complaint.userId).get();
      if (doc.exists) {
        return UserData.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint("Error fetching user data for complaint: $e");
    }
    return null;
  }

  Future<void> _updateStatus(String newStatus) async {
    // Capture context-dependent objects before async calls to avoid warnings.
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('complaints')
          .doc(widget.complaint.id)
          .update({'status': newStatus});
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus')),
      );
      navigator.pop();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Future<void> _launchMap(GeoPoint location) async {
    final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}");
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Could not open map.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Complaint Details'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (widget.complaint.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              // --- MODIFIED IMAGE WIDGET ---
              child: Image.network(
                widget.complaint.imageUrl!,
                fit: BoxFit.contain, // Changed from cover to contain
                // Removed fixed height to allow natural aspect ratio
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Icon(Icons.error, color: Colors.red, size: 50));
                },
              ),
              // --- END MODIFICATION ---
            ),
          const SizedBox(height: 24),
          _buildDetailRow('Type:', widget.complaint.type),
          _buildDetailRow('Description:', widget.complaint.description),
          _buildDetailRow('Submitted On:', DateFormat('d MMM yyyy, h:mm a').format(widget.complaint.createdAt.toDate())),
          _buildDetailRow('Status:', widget.complaint.status, isStatus: true),
          const Divider(height: 30, color: Colors.white24),
          _buildUserData(),
          if (widget.complaint.location != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: OutlinedButton.icon(
                onPressed: () => _launchMap(widget.complaint.location!),
                icon: const Icon(Icons.map_outlined),
                label: const Text("View on Map"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.cyanAccent,
                  side: const BorderSide(color: Colors.cyanAccent),
                ),
              ),
            ),
          const SizedBox(height: 30),
          _buildStatusButtons(),
        ],
      ),
    );
  }

  Widget _buildUserData() {
    return FutureBuilder<UserData?>(
      future: _userDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Text('Could not load user details.', style: TextStyle(color: Colors.redAccent));
        }
        final user = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Submitted By:', user.name),
            _buildDetailRow('Contact:', user.phoneNumber ?? 'Not provided'),
          ],
        );
      },
    );
  }

  Widget _buildStatusButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Update Status:', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => _updateStatus('In Progress'),
          // --- MODIFIED BUTTON STYLE ---
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black), // Added black text color
          child: const Text('Mark as In Progress'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => _updateStatus('Resolved'),
          // --- MODIFIED BUTTON STYLE ---
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.black), // Added black text color
          child: const Text('Mark as Resolved'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String title, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isStatus ? Colors.orangeAccent : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:aquasense/models/complaint_model.dart';
import 'package:aquasense/screens/supervisor/complaint_detail_screen.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:flutter/material.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/models/billing_info.dart';
import 'package:aquasense/screens/billing/components/billing_list_tile.dart';
import 'package:aquasense/screens/complaints/components/complaint_list_tile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

class WardMemberDetailScreen extends StatefulWidget {
  final UserData member;
  const WardMemberDetailScreen({super.key, required this.member});

  @override
  State<WardMemberDetailScreen> createState() => _WardMemberDetailScreenState();
}

class _WardMemberDetailScreenState extends State<WardMemberDetailScreen> {
  late Future<Map<String, dynamic>> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _fetchMemberDetails();
  }

  Future<Map<String, dynamic>> _fetchMemberDetails() async {
    String address = 'Not available';
    final requestQuery = await FirebaseFirestore.instance
        .collection('connection_requests')
        .where('userId', isEqualTo: widget.member.uid)
        .limit(1)
        .get();
    if (requestQuery.docs.isNotEmpty) {
      address = requestQuery.docs.first.data()['address'] ?? 'Not available';
    }

    int lastReading = 0;
    double avgConsumption = 0.0;
    final billingQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.member.uid)
        .collection('billingHistory')
        .orderBy('date', descending: true)
        .get();

    if (billingQuery.docs.isNotEmpty) {
      final history = billingQuery.docs.map((doc) => BillingInfo.fromFirestore(doc)).toList();
      lastReading = history.first.reading;

      List<double> consumptionData = [];
      if (history.length > 1) {
        final sortedHistory = List<BillingInfo>.from(history)..sort((a, b) => a.date.compareTo(b.date));
        for (int i = 1; i < sortedHistory.length; i++) {
          final consumption = sortedHistory[i].reading - sortedHistory[i - 1].reading;
          consumptionData.add(consumption.toDouble());
        }
        if (consumptionData.isNotEmpty) {
          avgConsumption = consumptionData.reduce((a, b) => a + b) / consumptionData.length;
        }
      }
    }

    return {
      'address': address,
      'lastReading': lastReading,
      'avgConsumption': avgConsumption,
    };
  }

  Future<void> _launchMap(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    GeoPoint? location;
    try {
      final requestQuery = await FirebaseFirestore.instance
          .collection('connection_requests')
          .where('userId', isEqualTo: widget.member.uid)
          .where('currentStatus', isEqualTo: 'Completed')
          .limit(1)
          .get();
      if (requestQuery.docs.isNotEmpty) {
        location = requestQuery.docs.first.data()['finalConnectionLocation'] as GeoPoint?;
      }
      if (location != null) {
        final uri = Uri.parse("https://maps.google.com/?q=${location.latitude},${location.longitude}");
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch map.';
        }
      } else {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('No location data found for this user.')));
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error launching map: $e')));
    }
  }

  // --- MODIFIED FUNCTION: REQUESTS DELETION INSTEAD OF DIRECTLY DELETING ---
  Future<void> _requestUserDeletion(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    bool? confirmRequest = await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        title: const Text('Request User Deletion?', style: TextStyle(color: Colors.white)),
        content: Text('This will flag ${widget.member.name} for deletion by an administrator. Are you sure?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('REQUEST', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmRequest == true) {
      try {
        // This is a simple Firestore write, which App Check will allow.
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.member.uid)
            .update({'deletionRequested': true});

        if (mounted) _showSuccessAnimationDialog(navigator, "Deletion Requested", "The admin has been notified.");

      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showSuccessAnimationDialog(NavigatorState navigator, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 80)
                .animate()
                .scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              navigator.pop(); // Close dialog
              if (navigator.canPop()) {
                navigator.pop(); // Go back from detail screen
              }
            },
            child: const Text("OK", style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: Text(widget.member.name),
        backgroundColor: const Color(0xFF152D4E),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined, color: Colors.orangeAccent),
            onPressed: () => _requestUserDeletion(context),
            tooltip: 'Request User Deletion',
          )
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Could not load member details.', style: TextStyle(color: Colors.redAccent)));
          }

          final details = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildInfoCard(details),
              _buildBillingHistory(),
              _buildComplaintStatus(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> details) {
    return Card(
      color: Colors.white.withAlpha(15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.email_outlined, widget.member.email),
            _buildDetailRow(Icons.home_outlined, details['address']),
            _buildDetailRow(Icons.speed_outlined, 'Last Reading: ${details['lastReading']} m³'),
            _buildDetailRow(Icons.water_drop_outlined, 'Avg. Consumption: ${details['avgConsumption'].toStringAsFixed(1)} m³'),
            const Divider(color: Colors.white24, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(Icons.call_outlined, 'Call User', () async {
                  if (widget.member.phoneNumber != null) {
                    final uri = Uri.parse('tel:${widget.member.phoneNumber}');
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  }
                }),
                _buildActionButton(Icons.email_outlined, 'Email User', () async {
                  final uri = Uri.parse('mailto:${widget.member.email}');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                }),
                _buildActionButton(Icons.map_outlined, 'View on Map', () => _launchMap(context)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.cyanAccent),
          onPressed: onPressed,
          iconSize: 28,
        ),
        Text(label, style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(widget.member.uid).collection('billingHistory')
          .orderBy('date', descending: true).limit(5).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final bills = snapshot.data!.docs.map((doc) => BillingInfo.fromFirestore(doc)).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text('Recent Billing History', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bills.length,
              itemBuilder: (context, index) => BillingListTile(bill: bills[index]),
            ),
            const Divider(height: 30, color: Colors.white24),
          ],
        );
      },
    );
  }

  Widget _buildComplaintStatus() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints').where('userId', isEqualTo: widget.member.uid)
          .where('status', isNotEqualTo: 'Resolved').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final complaints = snapshot.data!.docs.map((doc) => Complaint.fromFirestore(doc)).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Active Complaints', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: complaints.length,
              itemBuilder: (context, index) {
                final complaint = complaints[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(SlideFadeRoute(
                      page: ComplaintDetailScreen(complaint: complaint),
                    ));
                  },
                  child: ComplaintListTile(complaint: complaint),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
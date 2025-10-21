import 'package:aquasense/models/billing_info.dart';
import 'package:aquasense/models/complaint_model.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/screens/supervisor/billing/components/complaint_summary_card.dart';
import 'package:aquasense/screens/supervisor/billing/components/meter_input_widget.dart';
import 'package:aquasense/screens/supervisor/billing/components/mini_usage_chart.dart';
import 'package:aquasense/screens/supervisor/billing/components/user_detail_card.dart';
import 'package:aquasense/services/billing_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

class EnterReadingScreen extends StatefulWidget {
  final UserData citizen;

  const EnterReadingScreen({super.key, required this.citizen});

  @override
  State<EnterReadingScreen> createState() => _EnterReadingScreenState();
}

class _EnterReadingScreenState extends State<EnterReadingScreen> {
  final BillingService _billingService = BillingService();
  Future<Map<String, dynamic>>? _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _fetchDetails();
  }

  // --- START: NEW FUNCTION ---
  // This function will be called to refresh the data on the screen.
  void _refreshDetails() {
    setState(() {
      _detailsFuture = _fetchDetails();
    });
  }
  // --- END: NEW FUNCTION ---

  Future<Map<String, dynamic>> _fetchDetails() async {
    final lastBill = await _billingService.getLastBill(widget.citizen.uid);
    final billingHistory = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.citizen.uid)
        .collection('billingHistory')
        .orderBy('date', descending: true)
        .limit(6)
        .get();

    final unresolvedComplaints = await FirebaseFirestore.instance
        .collection('complaints')
        .where('wardId', isEqualTo: widget.citizen.wardId)
        .where('userId', isEqualTo: widget.citizen.uid)
        .where('status', isNotEqualTo: 'Resolved')
        .get();

    final unpaidBills = await _billingService.getUnpaidBills(widget.citizen.uid);

    return {
      'lastBill': lastBill,
      'billingHistory': billingHistory.docs
          .map((doc) => BillingInfo.fromFirestore(doc))
          .toList(),
      'unresolvedComplaints': unresolvedComplaints.docs
          .map((doc) => Complaint.fromFirestore(doc))
          .toList(),
      'unpaidBills': unpaidBills,
    };
  }

  void _showSuccessDialog(String message) {
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/animations/success_checkmark.json',
                repeat: false, height: 100),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              navigator.pop();
              navigator.pop();
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
        title: Text(widget.citizen.name),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text(
                'Could not load user details.',
                style: TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (!widget.citizen.hasActiveConnection) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 60),
                    const SizedBox(height: 20),
                    const Text(
                      "This user does not have an active connection. A bill cannot be generated.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 18),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("Go Back"),
                    )
                  ],
                ),
              ),
            );
          }

          final details = snapshot.data!;
          final BillingInfo? lastBill = details['lastBill'];
          final List<BillingInfo> history = details['billingHistory'];
          final List<Complaint> complaints = details['unresolvedComplaints'];
          final List<BillingInfo> unpaidBills = details['unpaidBills'];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              UserDetailCard(citizen: widget.citizen),
              const SizedBox(height: 20),
              MeterInputWidget(
                lastReading: lastBill?.reading ?? 0,
                onSuccess: _showSuccessDialog,
                citizen: widget.citizen,
                unpaidBills: unpaidBills,
                billingHistory: history,
              ),
              const SizedBox(height: 20),
              if (complaints.isNotEmpty)
                ComplaintSummaryCard(
                  complaints: complaints,
                  onComplaintResolved: _refreshDetails,
                ),
              if (history.isNotEmpty) MiniUsageChart(billingHistory: history),
            ]
                .animate(interval: 100.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, curve: Curves.easeOut),
          );
        },
      ),
    );
  }
}
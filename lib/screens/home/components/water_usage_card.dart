import 'package:aquasense/models/billing_info.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/screens/billing/billing_history_screen.dart';
import 'package:aquasense/services/firestore_service.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class WaterUsageCard extends StatelessWidget {
  final UserData userData;
  final FirestoreService _firestoreService = FirestoreService();

  WaterUsageCard({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      sliver: SliverToBoxAdapter(
        child: StreamBuilder<List<BillingInfo>>(
          stream: _firestoreService.getAllUnpaidBillsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 190,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: Colors.cyanAccent),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final dueBills = snapshot.data!;
            final totalDue =
            dueBills.fold<double>(0, (sum, item) => sum + item.amount + item.currentFine);
            final billsDueCount = dueBills.length;

            return ClipRRect(
              borderRadius: BorderRadius.circular(25.0),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  // --- MODIFIED: Reduced padding to make the card more compact ---
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.withAlpha(38),
                        Colors.red.withAlpha(20)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25.0),
                    border:
                    Border.all(color: Colors.orangeAccent.withAlpha(51)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Amount Due',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14, // Reduced font size
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4), // Reduced spacing
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '₹',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 20, // Reduced font size
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            totalDue.toStringAsFixed(2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40, // Reduced font size
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8), // Reduced spacing
                      Text(
                        '$billsDueCount bill(s) currently overdue.',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 12), // Reduced spacing
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            SlideFadeRoute(
                                page: const BillingHistoryScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12), // Reduced padding
                          minimumSize: const Size(double.infinity, 44), // Reduced height
                        ),
                        child: const Text(
                          'View & Pay Bills',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(
                begin: 0.3, curve: Curves.easeOut);
          },
        ),
      ),
    );
  }
}
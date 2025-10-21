import 'package:aquasense/models/billing_info.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/screens/billing/bill_detail_screen.dart';
import 'package:aquasense/services/firestore_service.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aquasense/screens/billing/components/billing_list_tile.dart';

class BillingHistoryScreen extends StatefulWidget {
  const BillingHistoryScreen({super.key});

  @override
  State<BillingHistoryScreen> createState() => _BillingHistoryScreenState();
}

class _BillingHistoryScreenState extends State<BillingHistoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  Future<UserData?>? _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _fetchUserData();
  }

  Future<UserData?> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserData.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint("Error fetching user data for billing: $e");
    }
    return null;
  }

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
        child: FutureBuilder<UserData?>(
            future: _userDataFuture,
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!userSnapshot.hasData) {
                return const Center(child: Text("Could not load user data."));
              }
              final userData = userSnapshot.data!;
              return CustomScrollView(
                slivers: [
                  const SliverAppBar(
                    backgroundColor: Colors.transparent,
                    expandedHeight: 120.0,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text('Billing History',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: StreamBuilder<List<BillingInfo>>(
                      stream: _firestoreService.getBillingHistoryStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(
                                  color: Colors.cyanAccent),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                'Failed to load billing history.',
                                style: TextStyle(color: Colors.red[300]),
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text(
                                'No billing records found.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          );
                        }

                        final bills = snapshot.data!;
                        return ListView.builder(
                          itemCount: bills.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(SlideFadeRoute(
                                  page: BillDetailScreen(
                                    bill: bills[index],
                                    userData: userData,
                                  ),
                                ));
                              },
                              child: BillingListTile(bill: bills[index])
                                  .animate()
                                  .fadeIn(
                                  delay: (100 * index).ms,
                                  duration: 400.ms)
                                  .slideY(begin: 0.5, curve: Curves.easeOut),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            }),
      ),
    );
  }
}


import 'package:aquasense/models/connection_request_model.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/models/water_tank_model.dart';
import 'package:aquasense/screens/announcements/announcements_screen.dart';
import 'package:aquasense/screens/billing/billing_history_screen.dart';
import 'package:aquasense/screens/connections/apply_connection_screen.dart';
import 'package:aquasense/screens/connections/connection_status_detail_screen.dart';
import 'package:aquasense/screens/home/components/apply_connection_card.dart';
import 'package:aquasense/screens/home/components/connection_status_card.dart';
import 'package:aquasense/screens/home/components/prediction_card.dart'; // Import the new card
import 'package:aquasense/screens/report/report_leak_screen.dart';
import 'package:aquasense/screens/statistics/usage_statistics_screen.dart';
import 'package:aquasense/services/ml_service.dart'; // Import the new service
import 'package:aquasense/utils/page_transition.dart';
import 'package:aquasense/widgets/animated_water_tank.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aquasense/screens/home/components/home_header.dart';
import 'package:aquasense/screens/home/components/quick_action_card.dart';
import 'package:aquasense/screens/home/components/water_usage_card.dart';
import 'package:aquasense/utils/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final MLService _mlService = MLService(); // Add ML service instance
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late Stream<UserData?> _userDataStream;
  Future<ConsumptionCategory?>? _predictionFuture; // To hold the prediction result

  @override
  void initState() {
    super.initState();
    _userDataStream = fetchUserDataStream();
  }

  Stream<UserData?> fetchUserDataStream() {
    if (currentUser != null) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .snapshots()
          .map((doc) {
        if (doc.exists) {
          final userData = UserData.fromFirestore(doc);
          // Trigger the prediction when user data is fetched
          if (userData.hasActiveConnection && _predictionFuture == null) {
            _predictionFuture = _mlService.predictConsumptionCategory(
              wardId: userData.wardId,
              userId: userData.uid,
            );
          }
          return userData;
        }
        return null;
      }).handleError((error) {
        debugPrint("Error fetching user data stream: $error");
        return null;
      });
    }
    return Stream.value(null);
  }

  Stream<ConnectionRequest?> getConnectionRequestStream() {
    if (currentUser == null) {
      return Stream.value(null);
    }
    return FirebaseFirestore.instance
        .collection('connection_requests')
        .where('userId', isEqualTo: currentUser!.uid)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }
      return ConnectionRequest.fromFirestore(snapshot.docs.first);
    });
  }

  void _showFeatureDisabledDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Feature Locked", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This feature will be unlocked once your water connection is active.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK", style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _showSupervisorContactDialog(BuildContext context, String wardId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    UserData? supervisor;

    try {
      final supervisorQuery = await FirebaseFirestore.instance
          .collection('supervisors')
          .where('wardId', isEqualTo: wardId)
          .limit(1)
          .get();

      if (supervisorQuery.docs.isNotEmpty) {
        supervisor = UserData.fromFirestore(supervisorQuery.docs.first);
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text("Error finding supervisor: $e")));
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Ward Supervisor Info", style: TextStyle(color: Colors.white)),
        content: supervisor == null
            ? const Text("No supervisor assigned to your ward yet.", style: TextStyle(color: Colors.white70))
            : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(supervisor.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.call, color: Colors.cyanAccent),
              title: Text(supervisor.phoneNumber ?? 'Not available', style: const TextStyle(color: Colors.white)),
              contentPadding: EdgeInsets.zero,
              onTap: supervisor.phoneNumber != null ? () async {
                final uri = Uri.parse('tel:${supervisor!.phoneNumber}');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              } : null,
            ),
            ListTile(
              leading: const Icon(Icons.alternate_email, color: Colors.cyanAccent),
              title: Text(supervisor.email, style: const TextStyle(color: Colors.white)),
              contentPadding: EdgeInsets.zero,
              onTap: () async {
                final uri = Uri.parse('mailto:${supervisor!.email}');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close", style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<UserData?>(
        stream: _userDataStream,
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (userSnapshot.hasError || !userSnapshot.hasData || userSnapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Could not load user data.', style: TextStyle(color: Colors.white)),
                  ElevatedButton(
                      onPressed: () => _authService.logoutUser(),
                      child: const Text("Logout"))
                ],
              ),
            );
          }

          final userData = userSnapshot.data!;

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CustomScrollView(
              slivers: [
                HomeHeader(
                  userName: userData.name,
                  onNotificationTap: () {
                    Navigator.of(context).push(
                      SlideFadeRoute(page: const AnnouncementsScreen()),
                    );
                  },
                ),

                if (userData.hasActiveConnection)
                  _buildWaterTankDisplay(userData.wardId)
                else
                  const SliverToBoxAdapter(child: SizedBox.shrink()),

                StreamBuilder<ConnectionRequest?>(
                    stream: getConnectionRequestStream(),
                    builder: (context, requestSnapshot) {
                      final hasConnectionRequest = requestSnapshot.hasData && requestSnapshot.data != null;
                      final noConnectionAndNoRequest = !userData.hasActiveConnection && !hasConnectionRequest;

                      if (noConnectionAndNoRequest) {
                        return _buildNoConnectionMessage();
                      }

                      if (userData.hasActiveConnection) {
                        return WaterUsageCard(userData: userData);
                      }

                      if (hasConnectionRequest) {
                        return ConnectionStatusCard(
                            request: requestSnapshot.data!,
                            onTap: () {
                              Navigator.of(context).push(
                                SlideFadeRoute(
                                  page: ConnectionStatusDetailScreen(request: requestSnapshot.data!),
                                ),
                              );
                            }
                        );
                      }

                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                ),

                // New FutureBuilder for the prediction card
                if (userData.hasActiveConnection && _predictionFuture != null)
                  FutureBuilder<ConsumptionCategory?>(
                    future: _predictionFuture,
                    builder: (context, predictionSnapshot) {
                      if (predictionSnapshot.connectionState == ConnectionState.done &&
                          predictionSnapshot.hasData &&
                          predictionSnapshot.data != null) {
                        return PredictionCard(category: predictionSnapshot.data!);
                      }
                      // You can return a loading indicator or an empty box while waiting
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    },
                  ),

                StreamBuilder<ConnectionRequest?>(
                    stream: getConnectionRequestStream(),
                    builder: (context, requestSnapshot) {
                      final hasConnectionRequest = requestSnapshot.hasData && requestSnapshot.data != null;
                      final shouldShowApplyCard = !userData.hasActiveConnection && !hasConnectionRequest;

                      if (shouldShowApplyCard) {
                        return ApplyConnectionCard(
                          onTap: () {
                            Navigator.of(context).push(
                              SlideFadeRoute(page: const ApplyConnectionScreen()),
                            );
                          },
                        );
                      }
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                ),

                _buildQuickActions(userData),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWaterTankDisplay(String wardId) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      sliver: SliverToBoxAdapter(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('water_tanks').doc(wardId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 190, child: Center(child: CircularProgressIndicator()));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const SizedBox.shrink();
            }

            final tank = WaterTank.fromFirestore(snapshot.data!);

            return SizedBox(
              height: 190,
              child: AnimatedWaterTank(
                waterLevel: tank.level,
                tankName: tank.tankName,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoConnectionMessage() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      sliver: SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.teal.withAlpha(30),
            borderRadius: BorderRadius.circular(25.0),
            border: Border.all(color: Colors.tealAccent.withAlpha(51)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, color: Colors.tealAccent, size: 30),
              SizedBox(width: 16),
              Text(
                'Apply for a connection to start.',
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(UserData userData) {
    return SliverPadding(
      padding: const EdgeInsets.all(24.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.25,
        ),
        delegate: SliverChildListDelegate(
          [
            QuickActionCard(
              title: 'Contact\nSupervisor',
              icon: Icons.support_agent_outlined,
              color: Colors.purpleAccent,
              onTap: () => _showSupervisorContactDialog(context, userData.wardId),
            ),

            QuickActionCard(
              title: 'Report a\nLeak',
              icon: Icons.water_drop_outlined,
              color: Colors.blueAccent,
              onTap: () {
                Navigator.of(context)
                    .push(SlideFadeRoute(page: const ReportLeakScreen()));
              },
            ),

            QuickActionCard(
              title: 'Billing\nHistory',
              icon: Icons.receipt_long_outlined,
              color: userData.hasActiveConnection ? Colors.orangeAccent : Colors.grey,
              onTap: () {
                if (userData.hasActiveConnection) {
                  Navigator.of(context)
                      .push(SlideFadeRoute(page: const BillingHistoryScreen()));
                } else {
                  _showFeatureDisabledDialog(context);
                }
              },
            ),

            QuickActionCard(
              title: 'Usage\nStatistics',
              icon: Icons.bar_chart_outlined,
              color: userData.hasActiveConnection ? Colors.greenAccent : Colors.grey,
              onTap: () {
                if (userData.hasActiveConnection) {
                  Navigator.of(context)
                      .push(SlideFadeRoute(page: const UsageStatisticsScreen()));
                } else {
                  _showFeatureDisabledDialog(context);
                }
              },
            ),
          ]
              .animate(interval: 100.ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.5, curve: Curves.easeOut),
        ),
      ),
    );
  }
}
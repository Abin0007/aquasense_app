import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/models/water_tank_model.dart';
import 'package:aquasense/screens/profile/profile_screen.dart';
import 'package:aquasense/screens/supervisor/billing/billing_dashboard_screen.dart';
import 'package:aquasense/screens/supervisor/settle_payments_screen.dart';
import 'package:aquasense/screens/supervisor/tank_levels_screen.dart';
import 'package:aquasense/screens/supervisor/view_complaints_screen.dart';
import 'package:aquasense/screens/supervisor/view_connection_requests_screen.dart';
import 'package:aquasense/screens/supervisor/ward_management/ward_member_list_screen.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:aquasense/widgets/animated_water_tank.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  late Future<UserData?> _supervisorDataFuture;
  // State variables to track if an alert has been shown
  bool _lowLevelAlertShown = false;
  bool _highLevelAlertShown = false;

  @override
  void initState() {
    super.initState();
    _supervisorDataFuture = _fetchSupervisorData();
  }

  Future<UserData?> _fetchSupervisorData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      final doc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserData.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint("Error fetching supervisor data: $e");
    }
    return null;
  }

  // --- NEW: Function to show a styled alert dialog ---
  void _showWaterLevelAlert(BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    // This ensures the dialog is shown only after the current build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Ensure the widget is still in the tree
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF152D4E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: color.withOpacity(0.5), width: 2),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 70)
                  .animate()
                  .scale(duration: 400.ms, curve: Curves.easeOutBack)
                  .then(delay: 200.ms)
                  .shake(hz: 4, duration: 300.ms),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("DISMISS", style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      body: FutureBuilder<UserData?>(
        future: _supervisorDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
                child: Text("Could not load supervisor data."));
          }

          final supervisorData = snapshot.data!;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('Supervisor Dashboard'),
                backgroundColor: const Color(0xFF152D4E),
                pinned: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.account_circle_outlined),
                    onPressed: () {
                      Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProfileScreen()));
                    },
                  ),
                ],
              ),
              const SliverToBoxAdapter(child: _TanksHeader()),
              _buildWaterTankDisplay(supervisorData.wardId),
              const SliverToBoxAdapter(child: _QuickActionsHeader()),
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildListDelegate(
                    [
                      _buildDashboardCard(
                        context,
                        title: 'Ward Members',
                        icon: Icons.group_outlined,
                        color: Colors.tealAccent,
                        onTap: () => Navigator.of(context).push(
                            SlideFadeRoute(page: const WardMemberListScreen())),
                      ),
                      _buildDashboardCard(
                        context,
                        title: 'View Complaints',
                        icon: Icons.list_alt_outlined,
                        color: Colors.orangeAccent,
                        onTap: () => Navigator.of(context).push(
                            SlideFadeRoute(page: const ViewComplaintsScreen())),
                      ),
                      _buildDashboardCard(
                        context,
                        title: 'Approve Connections',
                        icon: Icons.person_add_alt_1_outlined,
                        color: Colors.blueAccent,
                        onTap: () => Navigator.of(context).push(SlideFadeRoute(
                            page: const ViewConnectionRequestsScreen())),
                      ),
                      _buildDashboardCard(
                        context,
                        title: 'Generate Bill',
                        icon: Icons.receipt_long_outlined,
                        color: Colors.cyanAccent,
                        onTap: () => Navigator.of(context).push(SlideFadeRoute(
                            page: const BillingDashboardScreen())),
                      ),
                      _buildDashboardCard(
                        context,
                        title: 'Tank Levels',
                        icon: Icons.waves_outlined,
                        color: Colors.greenAccent,
                        onTap: () => Navigator.of(context)
                            .push(SlideFadeRoute(page: const TankLevelsScreen())),
                      ),
                      _buildDashboardCard(
                        context,
                        title: 'Settle Cash Payments',
                        icon: Icons.payment_outlined,
                        color: Colors.purpleAccent,
                        onTap: () => Navigator.of(context).push(
                            SlideFadeRoute(page: const SettlePaymentsScreen())),
                      ),
                    ].animate(interval: 100.ms).fadeIn().scale(delay: 200.ms),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWaterTankDisplay(String supervisorWardId) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      sliver: SliverToBoxAdapter(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('water_tanks')
              .doc(supervisorWardId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                  height: 190,
                  child: Center(child: CircularProgressIndicator()));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const SizedBox(
                height: 190,
                child: Center(
                    child: Text('No tank data available for your ward.',
                        style: TextStyle(color: Colors.white70))),
              );
            }

            final tank = WaterTank.fromFirestore(snapshot.data!);

            // --- ALERT LOGIC ---
            // Check for critical low level
            if (tank.level <= 15 && !_lowLevelAlertShown) {
              _showWaterLevelAlert(
                context,
                title: "Critical Low Level!",
                message: "Water level is at ${tank.level}%. Risk of motor damage from dry running. Immediate action required.",
                icon: Icons.error_outline,
                color: Colors.redAccent,
              );
              // Set the flag to true so the alert doesn't show again until the level normalizes
              _lowLevelAlertShown = true;
              _highLevelAlertShown = false; // Reset the other flag
            }
            // Check for nearly full level
            else if (tank.level >= 90 && !_highLevelAlertShown) {
              _showWaterLevelAlert(
                context,
                title: "Tank Almost Full",
                message: "Water level has reached ${tank.level}%. Prepare to turn off the motor to prevent overflow.",
                icon: Icons.notifications_active_outlined,
                color: Colors.amberAccent,
              );
              // Set the flag to true
              _highLevelAlertShown = true;
              _lowLevelAlertShown = false; // Reset the other flag
            }
            // Reset flags when the level is back in the normal range
            else if (tank.level > 15 && tank.level < 90) {
              if (_lowLevelAlertShown || _highLevelAlertShown) {
                // Use setState to rebuild and reset the flags
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _lowLevelAlertShown = false;
                      _highLevelAlertShown = false;
                    });
                  }
                });
              }
            }
            // --- END of Alert Logic ---

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

  Widget _buildDashboardCard(BuildContext context,
      {required String title,
        required IconData icon,
        required Color color,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withAlpha(30), color.withAlpha(60)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TanksHeader extends StatelessWidget {
  const _TanksHeader();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 16, top: 16, right: 16),
      child: Text('Live Tank Status',
          style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
    );
  }
}

class _QuickActionsHeader extends StatelessWidget {
  const _QuickActionsHeader();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8.0),
      child: Text('Quick Actions',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}


import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/models/water_tank_model.dart';
import 'package:aquasense/screens/announcements/announcements_screen.dart'; // Import general screen
import 'package:aquasense/screens/profile/profile_screen.dart';
import 'package:aquasense/screens/supervisor/billing/billing_dashboard_screen.dart';
import 'package:aquasense/screens/supervisor/manage_ward_announcements_screen.dart'; // Import supervisor's own screen
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
  bool _lowLevelAlertShown = false;
  bool _highLevelAlertShown = false;

  // --- State for Announcement Indicator ---
  bool _hasNewAnnouncements = false;
  Stream<QuerySnapshot>? _newAnnouncementsStream;
  Timestamp? _lastReadTimestamp;
  UserData? _supervisorData; // Store supervisor data
  Stream<UserData?>? _userDataListener; // Listener for user data changes
  User? _currentUser; // Store current user

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _supervisorDataFuture = _fetchInitialSupervisorData(); // Fetch initial data quickly
    _setupUserDataListener(); // Listen for real-time user data changes
  }

  // Fetch initial data for faster loading
  Future<UserData?> _fetchInitialSupervisorData() async {
    if (_currentUser == null) return null;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
      if (doc.exists && mounted) { // Added mounted check
        final userData = UserData.fromFirestore(doc);
        // Only update state if still null (listener might be faster)
        if (_supervisorData == null) {
          _supervisorData = userData;
          _lastReadTimestamp = userData.lastReadAnnouncementsTimestamp;
          _setupNewAnnouncementsStream(); // Setup stream with initial data
        }
        return userData; // Return fetched data for FutureBuilder
      }
    } catch (e) {
      debugPrint("Error fetching initial supervisor data: $e");
    }
    return null; // Return null if fetch fails or user doesn't exist
  }


  // Listen for real-time updates to user data (like lastRead timestamp)
  void _setupUserDataListener() {
    if (_currentUser == null) return;
    _userDataListener = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .snapshots()
        .map((doc) => doc.exists ? UserData.fromFirestore(doc) : null)
        .handleError((error) {
      debugPrint("Error listening to user data: $error");
      return null;
    });

    _userDataListener?.listen((userData) {
      if (userData != null && mounted) {
        bool needsRebuildForData = false;
        // Check if supervisor data needs updating (for UI elements relying directly on it)
        if (_supervisorData == null || _supervisorData!.uid != userData.uid /* Add other fields if needed */) {
          _supervisorData = userData;
          needsRebuildForData = true; // Flag that core data changed
        }

        // Update last read timestamp and re-setup stream if it changed
        if (_lastReadTimestamp != userData.lastReadAnnouncementsTimestamp) {
          _lastReadTimestamp = userData.lastReadAnnouncementsTimestamp;
          // Also update the stored _supervisorData instance
          _supervisorData = userData;
          _setupNewAnnouncementsStream(); // Re-setup stream with new timestamp
        }

        // Trigger rebuild if core data changed and the initial future might not be complete yet
        if (needsRebuildForData) {
          setState(() {
            // If the future hasn't resolved yet, update it so FutureBuilder rebuilds
            _supervisorDataFuture = Future.value(userData);
          });
        }
      } else if (mounted) {
        // Handle case where user doc might be deleted while listening
        _supervisorData = null;
        // Trigger rebuild to show error/logout state if needed by FutureBuilder
        setState(() {
          _supervisorDataFuture = Future.value(null);
        });
      }
    });
  }

  // Setup the stream to listen for new announcements
  void _setupNewAnnouncementsStream() {
    if (_supervisorData == null) return;

    final query = FirebaseFirestore.instance
        .collection('announcements')
        .where('wardId', whereIn: [null, _supervisorData!.wardId]) // Global or own ward
        .orderBy('createdAt', descending: true);

    Stream<QuerySnapshot> effectiveStream;
    // If there's a last read timestamp, only query newer ones
    if (_lastReadTimestamp != null) {
      effectiveStream = query.where('createdAt', isGreaterThan: _lastReadTimestamp!).snapshots();
    } else {
      effectiveStream = query.limit(1).snapshots(); // Check if at least one exists if never read
    }

    // Assign to state variable and listen
    _newAnnouncementsStream = effectiveStream;
    _newAnnouncementsStream?.listen((snapshot) {
      if (mounted) {
        final bool hasNew = snapshot.docs.isNotEmpty;
        if (_hasNewAnnouncements != hasNew){ // Only call setState if value changes
          setState(() {
            _hasNewAnnouncements = hasNew;
          });
        }
      }
    }, onError: (error){
      debugPrint("Error listening to announcements stream: $error");
      if(mounted && _hasNewAnnouncements) { // Only call setState if value changes
        setState(() {
          _hasNewAnnouncements = false; // Assume no new ones on error
        });
      }
    });
  }


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
        future: _supervisorDataFuture, // Use the future for initial load state
        builder: (context, snapshot) {
          // Display loading indicator based on future OR if _supervisorData is still null
          // *** CORRECTED: Check future's connectionState ***
          if (snapshot.connectionState == ConnectionState.waiting || _supervisorData == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            // Handle error or null data case
            return const Center(
                child: Text("Could not load supervisor data.", style: TextStyle(color: Colors.redAccent)));
          }

          // Use the fetched data (_supervisorData) which is now guaranteed non-null
          final supervisorData = _supervisorData!;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('Supervisor Dashboard'),
                backgroundColor: const Color(0xFF152D4E),
                pinned: true,
                actions: [
                  // --- Announcement Icon with Indicator ---
                  IconButton(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.campaign_outlined),
                        if (_hasNewAnnouncements)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              width: 10, // Size of the dot
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    tooltip: 'View Announcements',
                    onPressed: () {
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => AnnouncementsScreen(userData: supervisorData))) // Pass user data
                          .then((_) {
                        // No explicit refresh needed here, the listener will handle it
                        debugPrint("Returned from announcements screen.");
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.account_circle_outlined),
                    tooltip: 'My Profile',
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
                sliver: SliverGrid.count(
                  crossAxisCount: 2, // Keep 2 columns
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1, // Adjust aspect ratio if needed
                  children: [
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
                      title: 'Manage Ward \nAnnouncements', // New Card
                      icon: Icons.add_comment_outlined,
                      color: Colors.lightBlueAccent,
                      onTap: () => Navigator.of(context).push(SlideFadeRoute(
                          page: ManageWardAnnouncementsScreen(wardId: supervisorData.wardId))),
                    ),
                    _buildDashboardCard(
                      context,
                      title: 'View Ward \nComplaints',
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
                      title: 'Settle Cash \nPayments',
                      icon: Icons.account_balance_wallet_outlined, // Changed Icon
                      color: Colors.purpleAccent,
                      onTap: () => Navigator.of(context).push(
                          SlideFadeRoute(page: const SettlePaymentsScreen())),
                    ),
                    // Add an empty container or another card if you need an even number
                    Container(), // Placeholder if needed for grid alignment
                  ].animate(interval: 100.ms).fadeIn().scale(delay: 200.ms),
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
            Icon(icon, size: 40, color: color), // Slightly smaller icon
            const SizedBox(height: 12), // Reduced spacing
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15, // Slightly smaller text
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Keep these helper classes ---
class _TanksHeader extends StatelessWidget {
  const _TanksHeader();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 0), // Reduce bottom padding
      child: Text('Live Tank Status',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), // Slightly smaller
    );
  }
}

class _QuickActionsHeader extends StatelessWidget {
  const _QuickActionsHeader();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0, bottom: 4.0), // Adjust padding
      child: Text('Quick Actions',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
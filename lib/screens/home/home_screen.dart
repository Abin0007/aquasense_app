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
// Note: HomeHeader is now defined within this file
import 'package:aquasense/screens/home/components/quick_action_card.dart';
import 'package:aquasense/screens/home/components/water_usage_card.dart';
import 'package:aquasense/utils/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async'; // Import async for StreamSubscription

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

  // --- State for Announcement Indicator ---
  bool _hasNewAnnouncements = false;
  StreamSubscription? _newAnnouncementsSubscription; // Renamed for clarity
  Timestamp? _lastReadTimestamp;
  UserData? _citizenData; // Store citizen data
  StreamSubscription? _userDataSubscription; // Renamed for clarity


  @override
  void initState() {
    super.initState();
    // Start listening for user data changes immediately
    _setupUserDataListener();
    // Use the listener stream as the primary source for the FutureBuilder
    _userDataStream = _userDataListenerStream(); // Helper to create the stream
    // Trigger an initial fetch as well for faster first load
    _fetchInitialCitizenData();
  }

  // --- NEW: Helper to create the user data stream ---
  Stream<UserData?> _userDataListenerStream() {
    if (currentUser == null) return Stream.value(null);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .snapshots()
        .map((doc) => doc.exists ? UserData.fromFirestore(doc) : null)
        .handleError((error) {
      debugPrint("Error listening to user data: $error");
      return null; // Propagate null on error
    });
  }
  // --- END NEW HELPER ---


  // Fetch initial data for faster loading
  Future<void> _fetchInitialCitizenData() async {
    if (currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (doc.exists && mounted) {
        final initialData = UserData.fromFirestore(doc);
        // Only update if _citizenData is still null (listener might be faster)
        if (_citizenData == null) {
          _citizenData = initialData;
          _lastReadTimestamp = initialData.lastReadAnnouncementsTimestamp;
          _setupNewAnnouncementsStream(); // Setup stream with initial data
          _triggerPredictionIfNeeded(initialData); // Trigger prediction
          setState(() {}); // Update UI if needed
        }
      }
    } catch (e) {
      debugPrint("Error fetching initial citizen data: $e");
    }
  }


  // Listen for real-time updates to user data (like lastRead timestamp)
  void _setupUserDataListener() {
    if (currentUser == null) return;
    // Use the helper stream
    _userDataSubscription = _userDataListenerStream().listen((userData) {
      if (userData != null && mounted) {
        bool needsRebuild = false;
        // Check if citizen data actually changed (to avoid unnecessary rebuilds)
        if (_citizenData == null || _citizenData!.uid != userData.uid || _citizenData!.name != userData.name /* add other relevant fields */) {
          _citizenData = userData;
          needsRebuild = true;
        }

        // Update last read timestamp and re-setup stream if it changed
        // Check if timestamp is actually different before resetting stream
        final newTimestamp = userData.lastReadAnnouncementsTimestamp;
        // --- FIX: Use direct comparison for Timestamps ---
        if (_lastReadTimestamp != newTimestamp) {
          // ---------------------------------------------
          _lastReadTimestamp = newTimestamp;
          _setupNewAnnouncementsStream(); // Re-setup stream with new timestamp
        }


        // Trigger prediction if needed (e.g., connection status changed)
        _triggerPredictionIfNeeded(userData);

        if (needsRebuild) {
          setState(() {}); // Trigger rebuild if core user data changed
        }
      } else if (mounted) {
        // Handle case where user doc might be deleted while listening
        _citizenData = null;
        setState(() {}); // Trigger rebuild to show error/logout state
      }
    });
  }


  // Setup the stream to listen for new announcements
  void _setupNewAnnouncementsStream() {
    // Cancel previous subscription if exists
    _newAnnouncementsSubscription?.cancel();

    if (_citizenData == null || _citizenData!.wardId.isEmpty) {
      // If wardId is empty (e.g., during profile completion), only listen for global
      _listenForAnnouncements(FirebaseFirestore.instance
          .collection('announcements')
          .where('wardId', isEqualTo: null) // Global only
          .orderBy('createdAt', descending: true));
      return;
    };

    // Listen for announcements newer than last read, in relevant wards
    Query query = FirebaseFirestore.instance
        .collection('announcements')
        .where('wardId', whereIn: [null, _citizenData!.wardId]) // Global or own ward
        .orderBy('createdAt', descending: true);

    // Apply timestamp filter if available
    if (_lastReadTimestamp != null) {
      query = query.where('createdAt', isGreaterThan: _lastReadTimestamp!);
    } else {
      // If never read, limit to 1 to just check existence easily
      query = query.limit(1);
    }

    _listenForAnnouncements(query);
  }

  // Helper to actually listen to the announcement query stream
  void _listenForAnnouncements(Query query) {
    _newAnnouncementsSubscription = query.snapshots().listen((snapshot) {
      if (mounted) {
        final bool hasNew = snapshot.docs.isNotEmpty;
        // Only call setState if the value actually changes
        if (_hasNewAnnouncements != hasNew) {
          setState(() {
            _hasNewAnnouncements = hasNew;
          });
        }
      }
    }, onError: (error) {
      debugPrint("Error listening to announcements stream: $error");
      // Only call setState if the value changes
      if (mounted && _hasNewAnnouncements) {
        setState(() {
          _hasNewAnnouncements = false; // Assume no new ones on error
        });
      }
    });
  }

  @override
  void dispose() {
    _newAnnouncementsSubscription?.cancel(); // Cancel listener
    _userDataSubscription?.cancel(); // Cancel user data listener
    super.dispose();
  }


  // Helper to trigger prediction
  void _triggerPredictionIfNeeded(UserData userData) {
    if (userData.hasActiveConnection && _predictionFuture == null) {
      // Use mounted check before async operation and setState
      if(mounted){
        _predictionFuture = _mlService.predictConsumptionCategory(
          wardId: userData.wardId,
          userId: userData.uid,
        );
        // Optional: Trigger rebuild if prediction card relies on this future state
        // setState((){});
      }
    } else if (!userData.hasActiveConnection && _predictionFuture != null) {
      // Reset future if connection becomes inactive
      if(mounted){
        setState(() {
          _predictionFuture = null;
        });
      }
    }
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
      // Correct query: Look in 'users' collection with role 'supervisor' and matching wardId
      final supervisorQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('wardId', isEqualTo: wardId)
          .where('role', isEqualTo: 'supervisor') // Added role filter
          .limit(1)
          .get();

      if (supervisorQuery.docs.isNotEmpty) {
        supervisor = UserData.fromFirestore(supervisorQuery.docs.first);
      }
    } catch (e) {
      if (!mounted) return;
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
        stream: _userDataStream, // Use the listener stream
        builder: (context, userSnapshot) {
          // Show loading if listener hasn't provided data yet
          if (userSnapshot.connectionState == ConnectionState.waiting && _citizenData == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // Handle error or logout state if stream provides null or has error
          if (userSnapshot.hasError || !userSnapshot.hasData || userSnapshot.data == null) {
            // If _citizenData is also null, show proper error/logout
            if(_citizenData == null){
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Could not load user data.', style: TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 10),
                    ElevatedButton(
                        onPressed: () => _authService.logoutUser(),
                        child: const Text("Logout"))
                  ],
                ),
              );
            }
            // If listener fails but we have stale data, continue with stale data
            // This prevents flickering if there's a temporary network issue
          }

          // Use the latest available citizen data (_citizenData is updated by listener)
          // Ensure _citizenData is not null before proceeding
          final userData = _citizenData;
          if (userData == null) {
            // This case should ideally be handled by the error/loading logic above
            // but added as a safeguard.
            return const Center(child: Text('User data not available.', style: TextStyle(color: Colors.orangeAccent)));
          }


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
                // --- Pass indicator status to HomeHeader ---
                HomeHeader(
                  userName: userData.name,
                  hasNewAnnouncements: _hasNewAnnouncements, // Pass the flag
                  onNotificationTap: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AnnouncementsScreen(userData: userData)) // Pass user data
                    ).then((_) {
                      // Trigger a manual check/reset of the stream after returning
                      // This ensures the dot clears immediately if the timestamp was updated
                      debugPrint("Returned from announcements screen. Re-checking announcements.");
                      // Resetting the stream ensures it uses the potentially updated timestamp
                      _setupNewAnnouncementsStream();
                    });
                  },
                ),
                // --- End Header Update ---

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
                      if (predictionSnapshot.connectionState == ConnectionState.waiting) {
                        // Optional: Show a shimmer or placeholder while predicting
                        return const SliverToBoxAdapter(child: SizedBox(height: 100)); // Example placeholder height
                      }
                      if (predictionSnapshot.hasData && predictionSnapshot.data != null) {
                        return PredictionCard(category: predictionSnapshot.data!);
                      }
                      // Don't show anything if no prediction or error
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
              return const SizedBox.shrink(); // Hide if no tank data
            }

            final tank = WaterTank.fromFirestore(snapshot.data!);

            return SizedBox(
              height: 190, // Ensure fixed height for layout
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
              Expanded( // Allow text to wrap
                child: Text(
                  'Apply for a connection to access billing & usage features.',
                  textAlign: TextAlign.center, // Center align text
                  style: TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
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
              title: 'Report an\nIssue', // Updated text slightly
              icon: Icons.report_problem_outlined, // Changed Icon
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

// --- UPDATED HomeHeader Class ---
class HomeHeader extends StatelessWidget {
  final String userName;
  final VoidCallback onNotificationTap;
  final bool hasNewAnnouncements; // Add this

  const HomeHeader({
    super.key,
    required this.userName,
    required this.onNotificationTap,
    required this.hasNewAnnouncements, // Require it
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 40, bottom: 10),
      sliver: SliverToBoxAdapter(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // --- Icon with Indicator ---
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none, // Allow dot to overflow
                children: [
                  // --- CHANGE ICON BACK TO BELL ---
                  const Icon(Icons.notifications_outlined, color: Colors.white, size: 30),
                  // -------------------------------
                  if (hasNewAnnouncements)
                    Positioned(
                      top: -4, // Adjust position as needed
                      right: -4, // Adjust position as needed
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
              onPressed: onNotificationTap,
            ),
            // --- End Icon Update ---
          ],
        ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.2, curve: Curves.easeOut),
      ),
    );
  }
}
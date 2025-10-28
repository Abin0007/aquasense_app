import 'package:aquasense/models/connection_request_model.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/models/water_tank_model.dart';
import 'package:aquasense/screens/announcements/announcements_screen.dart';
import 'package:aquasense/screens/billing/billing_history_screen.dart';
import 'package:aquasense/screens/connections/apply_connection_screen.dart';
import 'package:aquasense/screens/connections/connection_status_detail_screen.dart';
import 'package:aquasense/screens/home/components/apply_connection_card.dart';
import 'package:aquasense/screens/home/components/connection_status_card.dart';
import 'package:aquasense/screens/home/components/prediction_card.dart'; // Import the card
import 'package:aquasense/services/ml_service.dart'; // Import ML Service for the enum
import 'package:aquasense/models/billing_info.dart'; // Import BillingInfo
import 'package:aquasense/services/firestore_service.dart'; // Import FirestoreService
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
import 'package:flutter/foundation.dart'; // Import for debugPrint

// --- Import the missing screen files ---
import 'package:aquasense/screens/report/report_leak_screen.dart'; // <-- MAKE SURE THIS IMPORT IS HERE
import 'package:aquasense/screens/statistics/usage_statistics_screen.dart';
// --- End Imports ---

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  // final MLService _mlService = MLService(); // Temporarily removed for client-side calculation
  final FirestoreService _firestoreService = FirestoreService(); // Added for billing history
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late Stream<UserData?> _userDataStream;
  ConsumptionCategory? _clientSidePredictionResult; // State for client-side result
  StreamSubscription? _billingHistorySubscription; // Subscription for billing data

  // --- State for Announcement Indicator ---
  bool _hasNewAnnouncements = false;
  StreamSubscription? _newAnnouncementsSubscription;
  Timestamp? _lastReadTimestamp;
  UserData? _citizenData; // Store citizen data
  StreamSubscription? _userDataSubscription;


  @override
  void initState() {
    super.initState();
    debugPrint("HomeScreen: initState called.");
    _setupUserDataListener();
    _userDataStream = _userDataListenerStream();
    _fetchInitialCitizenData();
    // Setup listener for billing history to calculate prediction
    _setupBillingHistoryListener();
  }

  Stream<UserData?> _userDataListenerStream() {
    // Keep existing user data listener logic
    if (currentUser == null) return Stream.value(null);
    debugPrint("HomeScreen: Creating user data listener stream for ${currentUser!.uid}");
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .snapshots()
        .map((doc) {
      debugPrint("HomeScreen: User data stream received snapshot. Exists: ${doc.exists}");
      return doc.exists ? UserData.fromFirestore(doc) : null;
    })
        .handleError((error) {
      debugPrint("HomeScreen: Error listening to user data stream: $error");
      return null;
    });
  }

  Future<void> _fetchInitialCitizenData() async {
    // Keep existing initial fetch logic, but remove prediction trigger call
    if (currentUser == null) return;
    debugPrint("HomeScreen: Fetching initial citizen data for ${currentUser!.uid}");
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (doc.exists && mounted) {
        final initialData = UserData.fromFirestore(doc);
        debugPrint("HomeScreen: Initial citizen data fetched: Name - ${initialData.name}, Ward - ${initialData.wardId}, ActiveConn - ${initialData.hasActiveConnection}, LastRead: ${initialData.lastReadAnnouncementsTimestamp?.toDate()}");

        if (_citizenData == null) {
          debugPrint("HomeScreen: Setting initial _citizenData and triggering initial checks.");
          _citizenData = initialData;
          _lastReadTimestamp = initialData.lastReadAnnouncementsTimestamp;
          _setupNewAnnouncementsCheck();
          setState(() {}); // Update UI with initial user data
        } else {
          debugPrint("HomeScreen: _citizenData already set by listener, skipping initial data set.");
        }
      } else if (mounted) {
        debugPrint("HomeScreen: Initial citizen data fetch - Document does not exist.");
      }
    } catch (e) {
      debugPrint("HomeScreen: Error fetching initial citizen data: $e");
    }
  }

  void _setupUserDataListener() {
    // Keep existing user data listener logic, but modify prediction handling
    if (currentUser == null) return;
    debugPrint("HomeScreen: Setting up user data listener for ${currentUser!.uid}");
    _userDataSubscription = _userDataListenerStream().listen((userData) {
      debugPrint("HomeScreen: User data listener received update. UserData is null: ${userData == null}");
      if (userData != null && mounted) {
        debugPrint("HomeScreen: Listener update - User: ${userData.name}, Ward: ${userData.wardId}, ActiveConn: ${userData.hasActiveConnection}, LastRead: ${userData.lastReadAnnouncementsTimestamp?.toDate()}");
        bool needsRebuild = false;
        bool timestampChanged = false;
        bool connectionStatusChanged = (_citizenData?.hasActiveConnection ?? false) != userData.hasActiveConnection;


        // Update citizen data
        _citizenData = userData; // Always update _citizenData with the latest
        needsRebuild = true; // Assume rebuild needed, simplify logic

        // Handle timestamp changes
        final newTimestamp = userData.lastReadAnnouncementsTimestamp;
        if (_lastReadTimestamp != newTimestamp) {
          debugPrint("HomeScreen: lastReadAnnouncementsTimestamp changed.");
          _lastReadTimestamp = newTimestamp;
          timestampChanged = true;
        }

        // --- PREDICTION LOGIC (Client-Side Trigger) ---
        if (connectionStatusChanged) {
          debugPrint("HomeScreen: Connection status changed to ${userData.hasActiveConnection}.");
          if (userData.hasActiveConnection) {
            // If connection became active, ensure billing listener is set up
            _setupBillingHistoryListener(); // Re-setup or start listening
          } else {
            // If connection became inactive, clear prediction
            if (mounted) {
              setState(() {
                _clientSidePredictionResult = null;
                _billingHistorySubscription?.cancel(); // Stop listening to bills
                _billingHistorySubscription = null;
              });
            }
          }
        } else if (userData.hasActiveConnection && _billingHistorySubscription == null) {
          // If somehow listener isn't active but connection is, start it
          _setupBillingHistoryListener();
        }
        // --- END PREDICTION LOGIC ---

        if (timestampChanged) {
          _setupNewAnnouncementsCheck();
        }

        if (needsRebuild && mounted) {
          debugPrint("HomeScreen: Calling setState due to data/timestamp change.");
          setState(() {});
        } else if (mounted) {
          debugPrint("HomeScreen: No significant state change detected in user listener, skipping setState.");
        }

      } else if (mounted) {
        debugPrint("HomeScreen: User data listener received null data.");
        _citizenData = null;
        _billingHistorySubscription?.cancel(); // Stop listening if user logs out/deleted
        _billingHistorySubscription = null;
        setState(() {});
      }
    }, onError: (error) {
      debugPrint("HomeScreen: Error in user data listener stream: $error");
      if (mounted) {
        _citizenData = null;
        _billingHistorySubscription?.cancel();
        _billingHistorySubscription = null;
        setState(() {});
      }
    });
  }

  // --- NEW: Listener for Billing History ---
  void _setupBillingHistoryListener() {
    // If user has no active connection, or listener already exists, do nothing
    if (_citizenData == null || !_citizenData!.hasActiveConnection || _billingHistorySubscription != null) {
      debugPrint("HomeScreen: Skipping billing history listener setup. Active: ${_citizenData?.hasActiveConnection}, SubExists: ${_billingHistorySubscription != null}");
      // If connection is inactive, ensure prediction is cleared
      if (_citizenData != null && !_citizenData!.hasActiveConnection && _clientSidePredictionResult != null) {
        if (mounted) {
          setState(() => _clientSidePredictionResult = null);
        }
      }
      return;
    }

    debugPrint("HomeScreen: Setting up billing history listener for user ${currentUser!.uid}");
    _billingHistorySubscription = _firestoreService.getBillingHistoryStream().listen(
            (billingHistory) {
          debugPrint("HomeScreen: Received billing history update. Count: ${billingHistory.length}");
          _calculateClientSidePrediction(billingHistory);
        },
        onError: (error) {
          debugPrint("HomeScreen: Error listening to billing history: $error");
          if (mounted) {
            setState(() => _clientSidePredictionResult = null); // Clear prediction on error
          }
        }
    );
  }

  // --- NEW: Client-Side Prediction Calculation ---
  void _calculateClientSidePrediction(List<BillingInfo> history) {
    if (history.length < 2) {
      debugPrint("HomeScreen: Not enough billing history (<2) to calculate prediction.");
      if (mounted && _clientSidePredictionResult != null) {
        setState(() => _clientSidePredictionResult = null); // Clear if not enough data
      }
      return; // Need at least two readings to calculate consumption
    }

    // Sort history oldest to newest to calculate consumption correctly
    final sortedHistory = List<BillingInfo>.from(history)..sort((a, b) => a.date.compareTo(b.date));

    // Calculate average *monthly* consumption over the last few periods (e.g., up to 6)
    double totalConsumption = 0;
    int monthsCount = 0;
    int limit = 6; // Look at last 6 months max

    for (int i = sortedHistory.length - 1; i > 0 && monthsCount < limit; i--) {
      // Basic check for roughly monthly interval (can be refined)
      final daysDiff = sortedHistory[i].date.toDate().difference(sortedHistory[i-1].date.toDate()).inDays;
      if (daysDiff > 20 && daysDiff < 40) {
        final consumption = sortedHistory[i].reading - sortedHistory[i - 1].reading;
        if (consumption >= 0) { // Ignore potential negative readings from corrections
          totalConsumption += consumption;
          monthsCount++;
        }
      }
    }

    if (monthsCount == 0) {
      debugPrint("HomeScreen: No valid monthly intervals found in billing history.");
      if (mounted && _clientSidePredictionResult != null) {
        setState(() => _clientSidePredictionResult = null);
      }
      return;
    }

    final averageConsumption = totalConsumption / monthsCount;
    debugPrint("HomeScreen: Calculated average monthly consumption: ${averageConsumption.toStringAsFixed(1)} units over $monthsCount months.");

    // Apply thresholds (same as Cloud Function for consistency)
    final ConsumptionCategory predictedCategory;
    const EFFICIENT_THRESHOLD = 10.0;
    const AVERAGE_THRESHOLD = 25.0;
    const HIGH_THRESHOLD = 40.0;

    if (averageConsumption <= EFFICIENT_THRESHOLD) {
      predictedCategory = ConsumptionCategory.efficient;
    } else if (averageConsumption <= AVERAGE_THRESHOLD) {
      predictedCategory = ConsumptionCategory.average;
    } else if (averageConsumption <= HIGH_THRESHOLD) {
      predictedCategory = ConsumptionCategory.high;
    } else {
      predictedCategory = ConsumptionCategory.veryHigh;
    }
    debugPrint("HomeScreen: Client-side predicted category: $predictedCategory");


    // Update state if prediction changed
    if (mounted && _clientSidePredictionResult != predictedCategory) {
      setState(() {
        _clientSidePredictionResult = predictedCategory;
      });
    }
  }


  Future<void> _setupNewAnnouncementsCheck() async {
    // Keep existing announcement check logic
    _newAnnouncementsSubscription?.cancel();

    if (_citizenData == null) {
      debugPrint("HomeScreen: Cannot check announcements, _citizenData is null.");
      return;
    }
    debugPrint("HomeScreen: Checking for new announcements. WardId: ${_citizenData!.wardId}, LastRead: ${_lastReadTimestamp?.toDate()}");

    bool foundNew = false;
    try {
      Query globalQuery = FirebaseFirestore.instance
          .collection('announcements')
          .where('wardId', isEqualTo: null)
          .orderBy('createdAt', descending: true)
          .limit(1);
      if (_lastReadTimestamp != null) {
        globalQuery = globalQuery.where('createdAt', isGreaterThan: _lastReadTimestamp!);
      }
      final globalSnapshot = await globalQuery.get();
      if (globalSnapshot.docs.isNotEmpty) {
        debugPrint("HomeScreen: Found new global announcement.");
        foundNew = true;
      }

      if (!foundNew && _citizenData!.wardId.isNotEmpty) {
        Query wardQuery = FirebaseFirestore.instance
            .collection('announcements')
            .where('wardId', isEqualTo: _citizenData!.wardId)
            .orderBy('createdAt', descending: true)
            .limit(1);
        if (_lastReadTimestamp != null) {
          wardQuery = wardQuery.where('createdAt', isGreaterThan: _lastReadTimestamp!);
        }
        final wardSnapshot = await wardQuery.get();
        if (wardSnapshot.docs.isNotEmpty) {
          debugPrint("HomeScreen: Found new ward announcement.");
          foundNew = true;
        }
      }
    } catch (e) {
      debugPrint("HomeScreen: Error checking for new announcements: $e");
      foundNew = false;
    }

    if (mounted && _hasNewAnnouncements != foundNew) {
      debugPrint("HomeScreen: Announcement indicator state changed to $foundNew. Calling setState.");
      setState(() {
        _hasNewAnnouncements = foundNew;
      });
    } else if (mounted) {
      debugPrint("HomeScreen: Announcement indicator state remains $_hasNewAnnouncements.");
    }
  }


  @override
  void dispose() {
    debugPrint("HomeScreen: Disposing HomeScreen state.");
    _newAnnouncementsSubscription?.cancel();
    _userDataSubscription?.cancel();
    _billingHistorySubscription?.cancel(); // Dispose billing listener
    super.dispose();
  }




  Stream<ConnectionRequest?> getConnectionRequestStream() {
    // Keep existing connection request stream logic
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
    // Keep existing dialog logic
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
    // Keep existing dialog logic
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    UserData? supervisor;
    try {
      final supervisorQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('wardId', isEqualTo: wardId)
          .where('role', isEqualTo: 'supervisor')
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
        stream: _userDataStream,
        builder: (context, userSnapshot) {
          // Keep existing loading/error handling for user data
          if (userSnapshot.connectionState == ConnectionState.waiting && _citizenData == null) {
            debugPrint("HomeScreen Build: User Stream waiting, _citizenData is null -> Showing Loading");
            return const Center(child: CircularProgressIndicator());
          }
          if ((userSnapshot.hasError || !userSnapshot.hasData || userSnapshot.data == null) && _citizenData == null) {
            debugPrint("HomeScreen Build: User Stream error/no data AND _citizenData is null -> Showing Error/Logout.");
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

          final userData = _citizenData;
          if (userData == null) {
            debugPrint("HomeScreen Build: userData (_citizenData) is null after checks -> Showing Error.");
            return const Center(child: CircularProgressIndicator()); // Fallback loading
          }
          debugPrint("HomeScreen Build: Building UI for user ${userData.uid}, ActiveConnection: ${userData.hasActiveConnection}");

          // --- UI Code ---
          return Container(
            // Keep existing Container decoration (gradient)
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
                  hasNewAnnouncements: _hasNewAnnouncements,
                  onNotificationTap: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AnnouncementsScreen(userData: userData))
                    ).then((_) {
                      _setupNewAnnouncementsCheck();
                    });
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

                // --- Updated Prediction Section ---
                SliverToBoxAdapter(
                  child: Builder(
                      builder: (context) {
                        debugPrint("HomeScreen Build: Rendering Prediction Section. Active: ${userData.hasActiveConnection}, ClientResult: $_clientSidePredictionResult");
                        // Show the card *only* if connection is active AND the client-side result is available
                        if (userData.hasActiveConnection && _clientSidePredictionResult != null) {
                          debugPrint("HomeScreen Build: Showing PredictionCard with client result: $_clientSidePredictionResult");
                          // Use the imported ConsumptionCategory from ml_service.dart
                          return PredictionCard(category: _clientSidePredictionResult!);
                        }
                        // Otherwise, show nothing (no loading indicator needed for client-side calc)
                        else {
                          debugPrint("HomeScreen Build: Hiding Prediction Section.");
                          return const SizedBox.shrink();
                        }
                      }
                  ),
                ),
                // --- End Updated Prediction Section ---

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
    // Keep existing water tank display logic
    if (wardId.isEmpty) {
      debugPrint("HomeScreen: Skipping WaterTankDisplay, wardId is empty.");
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    debugPrint("HomeScreen: Building WaterTankDisplay for ward: $wardId");
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      sliver: SliverToBoxAdapter(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('water_tanks').doc(wardId).snapshots(),
          builder: (context, snapshot) {
            // ... existing tank builder logic ...
            if (snapshot.connectionState == ConnectionState.waiting) { return const SizedBox(height: 190, child: Center(child: CircularProgressIndicator())); }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              debugPrint("HomeScreen: No water tank data found for ward: $wardId");
              return const SizedBox.shrink();
            }
            final tank = WaterTank.fromFirestore(snapshot.data!);
            debugPrint("HomeScreen: Water tank data loaded for ward $wardId: Level ${tank.level}%");
            return SizedBox( height: 190, child: AnimatedWaterTank( waterLevel: tank.level, tankName: tank.tankName, ), );
          },
        ),
      ),
    );
  }

  Widget _buildNoConnectionMessage() {
    // Keep existing no connection message
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
    // Keep existing quick actions grid
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
              title: 'Report an\nIssue',
              icon: Icons.report_problem_outlined,
              color: Colors.blueAccent,
              onTap: () {
                Navigator.of(context)
                    .push(SlideFadeRoute(page: const ReportLeakScreen())); // This line had the error
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
                      .push(SlideFadeRoute(page: const UsageStatisticsScreen())); // Use the imported class
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

// --- Keep HomeHeader Class ---
class HomeHeader extends StatelessWidget {
  // ... existing HomeHeader code ...
  final String userName;
  final VoidCallback onNotificationTap;
  final bool hasNewAnnouncements;

  const HomeHeader({
    super.key,
    required this.userName,
    required this.onNotificationTap,
    required this.hasNewAnnouncements,
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
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined, color: Colors.white, size: 30),
                  if (hasNewAnnouncements)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 10,
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
          ],
        ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.2, curve: Curves.easeOut),
      ),
    );
  }
}
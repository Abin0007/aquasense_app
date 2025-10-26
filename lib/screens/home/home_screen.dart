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
import 'package:flutter/foundation.dart'; // Import for debugPrint

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
      // --- DEBUG PRINT ADDED ---
      debugPrint("HomeScreen: Error listening to user data stream: $error");
      // -------------------------
      return null; // Propagate null on error
    });
  }
  // --- END NEW HELPER ---


  // Fetch initial data for faster loading
  Future<void> _fetchInitialCitizenData() async {
    if (currentUser == null) return;
    // --- DEBUG PRINT ADDED ---
    debugPrint("HomeScreen: Fetching initial citizen data for ${currentUser!.uid}");
    // -------------------------
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (doc.exists && mounted) {
        final initialData = UserData.fromFirestore(doc);
        // --- DEBUG PRINT ADDED ---
        debugPrint("HomeScreen: Initial citizen data fetched: Name - ${initialData.name}, Ward - ${initialData.wardId}, ActiveConn - ${initialData.hasActiveConnection}");
        // -------------------------
        // Only update if _citizenData is still null (listener might be faster)
        if (_citizenData == null) {
          // --- DEBUG PRINT ADDED ---
          debugPrint("HomeScreen: Setting initial _citizenData");
          // -------------------------
          _citizenData = initialData;
          _lastReadTimestamp = initialData.lastReadAnnouncementsTimestamp;
          _setupNewAnnouncementsCheck(); // *** CHANGED: Use check function ***
          _triggerPredictionIfNeeded(initialData); // Trigger prediction
          setState(() {}); // Update UI if needed
        } else {
          // --- DEBUG PRINT ADDED ---
          debugPrint("HomeScreen: _citizenData already set by listener, skipping initial data set.");
          // -------------------------
        }
      } else if (mounted) {
        // --- DEBUG PRINT ADDED ---
        debugPrint("HomeScreen: Initial citizen data fetch - Document does not exist.");
        // -------------------------
      }
    } catch (e) {
      // --- DEBUG PRINT ADDED ---
      debugPrint("HomeScreen: Error fetching initial citizen data: $e");
      // -------------------------
    }
  }


  // Listen for real-time updates to user data (like lastRead timestamp)
  void _setupUserDataListener() {
    if (currentUser == null) return;
    // --- DEBUG PRINT ADDED ---
    debugPrint("HomeScreen: Setting up user data listener for ${currentUser!.uid}");
    // -------------------------
    // Use the helper stream
    _userDataSubscription = _userDataListenerStream().listen((userData) {
      // --- DEBUG PRINT ADDED ---
      debugPrint("HomeScreen: User data listener received update. UserData is null: ${userData == null}");
      // -------------------------
      if (userData != null && mounted) {
        // --- DEBUG PRINT ADDED ---
        // debugPrint("HomeScreen: Listener update - User: ${userData.name}, Ward: ${userData.wardId}, ActiveConn: ${userData.hasActiveConnection}, LastRead: ${userData.lastReadAnnouncementsTimestamp?.toDate()}");
        // -------------------------
        bool needsRebuild = false;
        bool timestampChanged = false; // Flag to check timestamp change

        // Check if citizen data actually changed (to avoid unnecessary rebuilds)
        if (_citizenData == null ||
            _citizenData!.uid != userData.uid ||
            _citizenData!.name != userData.name ||
            _citizenData!.hasActiveConnection != userData.hasActiveConnection || // Check connection status change
            _citizenData!.wardId != userData.wardId // Check ward change
        /* add other relevant fields */)
        {
          // --- DEBUG PRINT ADDED ---
          debugPrint("HomeScreen: Core user data changed, updating _citizenData and flagging for rebuild.");
          // -------------------------
          _citizenData = userData;
          needsRebuild = true;
        }

        // Update last read timestamp and re-setup stream if it changed
        final newTimestamp = userData.lastReadAnnouncementsTimestamp;
        // --- FIX: Use direct comparison for Timestamps ---
        if (_lastReadTimestamp != newTimestamp) {
          // ---------------------------------------------
          // --- DEBUG PRINT ADDED ---
          debugPrint("HomeScreen: lastReadAnnouncementsTimestamp changed. Old: ${_lastReadTimestamp?.toDate()}, New: ${newTimestamp?.toDate()}. Will re-check announcements.");
          // -------------------------
          _lastReadTimestamp = newTimestamp;
          timestampChanged = true; // Set flag
        }


        // Trigger prediction if needed (e.g., connection status changed)
        _triggerPredictionIfNeeded(userData); // Pass the LATEST userData

        // Re-check for new announcements if timestamp changed
        if (timestampChanged) {
          _setupNewAnnouncementsCheck(); // *** CHANGED: Use check function ***
        }

        if (needsRebuild && mounted) { // Double check mounted
          // --- DEBUG PRINT ADDED ---
          debugPrint("HomeScreen: Calling setState due to core user data change.");
          // -------------------------
          setState(() {}); // Trigger rebuild if core user data changed
        }
      } else if (mounted) {
        // Handle case where user doc might be deleted while listening
        // --- DEBUG PRINT ADDED ---
        debugPrint("HomeScreen: User data listener received null data, setting _citizenData to null and calling setState.");
        // -------------------------
        _citizenData = null;
        setState(() {}); // Trigger rebuild to show error/logout state
      }
    }, onError: (error) { // Add onError handling
      // --- DEBUG PRINT ADDED ---
      debugPrint("HomeScreen: Error in user data listener stream: $error");
      // -------------------------
      // Optionally handle the error, maybe show a message or attempt retry
      if (mounted) {
        _citizenData = null; // Assume data is invalid on error
        setState(() {});
      }
    });
  }

  // *** NEW FUNCTION: Check for new announcements without using whereIn ***
  Future<void> _setupNewAnnouncementsCheck() async {
    _newAnnouncementsSubscription?.cancel(); // Cancel any previous check listener

    if (_citizenData == null) {
      debugPrint("HomeScreen: Cannot check announcements, _citizenData is null.");
      return;
    }
    debugPrint("HomeScreen: Checking for new announcements. WardId: ${_citizenData!.wardId}, LastRead: ${_lastReadTimestamp?.toDate()}");

    bool foundNew = false;

    try {
      // 1. Check for new GLOBAL announcements
      Query globalQuery = FirebaseFirestore.instance
          .collection('announcements')
          .where('wardId', isEqualTo: null) // Global
          .orderBy('createdAt', descending: true)
          .limit(1); // Get only the latest

      if (_lastReadTimestamp != null) {
        globalQuery = globalQuery.where('createdAt', isGreaterThan: _lastReadTimestamp!);
      }

      final globalSnapshot = await globalQuery.get();
      if (globalSnapshot.docs.isNotEmpty) {
        debugPrint("HomeScreen: Found new global announcement.");
        foundNew = true;
      }

      // 2. Check for new WARD-SPECIFIC announcements (if not found globally and user has wardId)
      if (!foundNew && _citizenData!.wardId.isNotEmpty) {
        Query wardQuery = FirebaseFirestore.instance
            .collection('announcements')
            .where('wardId', isEqualTo: _citizenData!.wardId) // Ward specific
            .orderBy('createdAt', descending: true)
            .limit(1); // Get only the latest

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
      foundNew = false; // Assume no new ones on error
    }

    // Update state only if it changed and component is still mounted
    if (mounted && _hasNewAnnouncements != foundNew) {
      debugPrint("HomeScreen: Announcement indicator state changed to $foundNew. Calling setState.");
      setState(() {
        _hasNewAnnouncements = foundNew;
      });
    } else if (mounted) {
      debugPrint("HomeScreen: Announcement indicator state remains $_hasNewAnnouncements.");
    }

    // Optionally: Set up a periodic timer to re-run this check if needed,
    // or rely on the _userDataListener to trigger it when _lastReadTimestamp changes.
    // For simplicity, we rely on the listener for now.
  }
  // *** END NEW FUNCTION ***


  // --- REMOVED OLD _listenForAnnouncements function ---

  @override
  void dispose() {
    // --- DEBUG PRINT ADDED ---
    debugPrint("HomeScreen: Disposing HomeScreen state.");
    // -------------------------
    _newAnnouncementsSubscription?.cancel(); // Cancel listener (though not actively used now)
    _userDataSubscription?.cancel(); // Cancel user data listener
    super.dispose();
  }


  // Helper to trigger prediction
  void _triggerPredictionIfNeeded(UserData userData) {
    // --- DEBUG PRINT ADDED ---
    // Check if prediction should run
    if (userData.hasActiveConnection && _predictionFuture == null) {
      debugPrint("HomeScreen: Triggering prediction for user ${userData.uid} in ward ${userData.wardId}. HasActiveConnection: ${userData.hasActiveConnection}");
      if(mounted){
        // Wrap in setState because _predictionFuture is used in the build method
        setState(() {
          _predictionFuture = _mlService.predictConsumptionCategory(
            wardId: userData.wardId,
            userId: userData.uid,
          ).then((result) {
            // --- DEBUG PRINT ADDED ---
            debugPrint("HomeScreen: Prediction future completed inside .then(). Result: $result");
            // We need another setState *here* if the future completes *after* the initial build triggered by the first setState.
            if (mounted) {
              // Check if the state needs update *after* the future completes
              // This ensures the UI reflects the result if it wasn't ready during initial build
              setState(() {});
            }
            // -------------------------
            return result; // Return the result for the FutureBuilder
          }).catchError((error) {
            // --- DEBUG PRINT ADDED ---
            debugPrint("HomeScreen: Prediction future failed with error inside .catchError(): $error");
            if (mounted) {
              setState(() {}); // Rebuild to potentially remove loading indicator
            }
            // -------------------------
            return null; // Return null on error
          });
        });
      }
    } else if (!userData.hasActiveConnection && _predictionFuture != null) {
      debugPrint("HomeScreen: Resetting prediction future because user ${userData.uid} connection is inactive.");
      // Reset future if connection becomes inactive
      if(mounted){
        setState(() {
          _predictionFuture = null;
        });
      }
    } else if (userData.hasActiveConnection && _predictionFuture != null) {
      // Optional: Log if prediction is already in progress or complete
      debugPrint("HomeScreen: Prediction future already exists or is in progress for user ${userData.uid}.");
    } else if (!userData.hasActiveConnection && _predictionFuture == null) {
      debugPrint("HomeScreen: Prediction not triggered, user ${userData.uid} has no active connection.");
    }
    // --- END DEBUG PRINT ---
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
          // Show loading if listener hasn't provided data yet AND initial fetch hasn't completed
          if (userSnapshot.connectionState == ConnectionState.waiting && _citizenData == null) {
            // --- DEBUG PRINT ADDED ---
            debugPrint("HomeScreen Build: User Stream waiting, _citizenData is null -> Showing Loading");
            // -------------------------
            return const Center(child: CircularProgressIndicator());
          }

          // Handle error or logout state if stream provides null or has error, AND initial fetch failed/returned null
          if ((userSnapshot.hasError || !userSnapshot.hasData || userSnapshot.data == null) && _citizenData == null) {
            // --- DEBUG PRINT ADDED ---
            debugPrint("HomeScreen Build: User Stream error/no data AND _citizenData is null -> Showing Error/Logout. HasError: ${userSnapshot.hasError}, HasData: ${userSnapshot.hasData}");
            // -------------------------
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

          // Use the latest available citizen data (_citizenData is updated by listener or initial fetch)
          // Ensure _citizenData is not null before proceeding
          final userData = _citizenData;
          if (userData == null) {
            // --- DEBUG PRINT ADDED ---
            debugPrint("HomeScreen Build: userData (_citizenData) is null after checks -> Showing Error. This shouldn't normally happen.");
            // -------------------------
            // This case should ideally be handled by the error/loading logic above
            return const Center(child: Text('User data not available.', style: TextStyle(color: Colors.orangeAccent)));
          }
          // --- DEBUG PRINT ADDED ---
          // debugPrint("HomeScreen Build: Building UI for user ${userData.uid}, ActiveConnection: ${userData.hasActiveConnection}");
          // -------------------------


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
                    // --- DEBUG PRINT ADDED ---
                    debugPrint("HomeScreen: Tapped notification icon. Navigating to AnnouncementsScreen.");
                    // -------------------------
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AnnouncementsScreen(userData: userData)) // Pass user data
                    ).then((_) {
                      // Trigger a manual check/reset after returning
                      // --- DEBUG PRINT ADDED ---
                      debugPrint("HomeScreen: Returned from announcements screen. Re-checking announcements.");
                      // -------------------------
                      _setupNewAnnouncementsCheck(); // *** CHANGED: Use check function ***
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

                // --- DEBUG PRINT ADDED around FutureBuilder ---
                SliverToBoxAdapter(
                  child: Builder( // Use Builder to access context for debug print
                      builder: (context) {
                        // --- DEBUG PRINT ADDED ---
                        debugPrint("HomeScreen Build: Checking Prediction FutureBuilder conditions. hasActiveConnection: ${userData.hasActiveConnection}, _predictionFuture is null: ${_predictionFuture == null}");
                        // -------------------------
                        if (userData.hasActiveConnection && _predictionFuture != null) {
                          // --- DEBUG PRINT ADDED ---
                          debugPrint("HomeScreen Build: Rendering Prediction FutureBuilder.");
                          // -------------------------
                          return FutureBuilder<ConsumptionCategory?>(
                            future: _predictionFuture,
                            builder: (context, predictionSnapshot) {
                              // --- DEBUG PRINT ADDED ---
                              debugPrint("HomeScreen Build: Prediction FutureBuilder state: ${predictionSnapshot.connectionState}, hasData: ${predictionSnapshot.hasData}, data: ${predictionSnapshot.data}, hasError: ${predictionSnapshot.hasError}");
                              // -------------------------
                              if (predictionSnapshot.connectionState == ConnectionState.waiting) {
                                // --- DEBUG PRINT ADDED ---
                                debugPrint("HomeScreen Build: Prediction Future is waiting.");
                                // -------------------------
                                // Optional: Show a shimmer or placeholder while predicting
                                return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(strokeWidth: 2))); // Example placeholder
                              }
                              if (predictionSnapshot.hasError) {
                                // --- DEBUG PRINT ADDED ---
                                debugPrint("HomeScreen Build: Prediction Future failed with error: ${predictionSnapshot.error}");
                                // -------------------------
                                return const SizedBox.shrink(); // Don't show card on error
                              }
                              if (predictionSnapshot.hasData && predictionSnapshot.data != null) {
                                // --- DEBUG PRINT ADDED ---
                                debugPrint("HomeScreen Build: Prediction Future completed with data: ${predictionSnapshot.data}. Showing PredictionCard.");
                                // -------------------------
                                return PredictionCard(category: predictionSnapshot.data!);
                              }
                              // Don't show anything if no prediction or error
                              // --- DEBUG PRINT ADDED ---
                              debugPrint("HomeScreen Build: Prediction Future completed but hasData is false or data is null. Hiding card.");
                              // -------------------------
                              return const SizedBox.shrink();
                            },
                          );
                        } else {
                          // --- DEBUG PRINT ADDED ---
                          debugPrint("HomeScreen Build: Condition for Prediction FutureBuilder not met. Skipping.");
                          // -------------------------
                          return const SizedBox.shrink(); // Return empty if condition isn't met
                        }
                      }
                  ),
                ),
                // --- END DEBUG PRINT ---


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
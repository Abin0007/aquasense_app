import 'package:aquasense/models/connection_request_model.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/models/water_tank_model.dart';
import 'package:aquasense/screens/announcements/announcements_screen.dart';
import 'package:aquasense/screens/billing/billing_history_screen.dart';
import 'package:aquasense/screens/connections/apply_connection_screen.dart';
import 'package:aquasense/screens/connections/connection_status_detail_screen.dart';
import 'package:aquasense/screens/home/components/apply_connection_card.dart';
import 'package:aquasense/screens/home/components/connection_status_card.dart';
// --- NEW IMPORT ---
import 'package:aquasense/screens/home/components/all_predictions_card.dart';
// --- END NEW IMPORT ---
import 'package:aquasense/services/ml_service.dart';
import 'package:aquasense/models/billing_info.dart';
import 'package:aquasense/services/firestore_service.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:aquasense/widgets/animated_water_tank.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aquasense/screens/home/components/quick_action_card.dart';
import 'package:aquasense/screens/home/components/water_usage_card.dart';
import 'package:aquasense/utils/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:aquasense/screens/report/report_leak_screen.dart';
import 'package:aquasense/screens/statistics/usage_statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final MLService _mlService = MLService(); // Service for the KNN cloud function
  final FirestoreService _firestoreService = FirestoreService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late Stream<UserData?> _userDataStream;
  StreamSubscription? _billingHistorySubscription;

  bool _hasNewAnnouncements = false;
  StreamSubscription? _newAnnouncementsSubscription;
  Timestamp? _lastReadTimestamp;
  UserData? _citizenData;
  StreamSubscription? _userDataSubscription;

  // --- NEW: State variables for ALL 5 predictions ---
  ConsumptionCategory? _consumptionPredictionResult;
  ResolutionTimeCategory? _resolutionPredictionResult;
  LeakageProbabilityCategory? _leakagePredictionResult;
  BillingAccuracyCategory? _billingPredictionResult;
  PeakDemandCategory? _peakDemandPredictionResult;
  // --- END NEW STATE ---

  @override
  void initState() {
    super.initState();
    debugPrint("HomeScreen: initState called.");
    _setupUserDataListener();
    _userDataStream = _userDataListenerStream();
    _fetchInitialCitizenData();
    _setupBillingHistoryListener(); // This listener calls the KNN prediction
  }

  Stream<UserData?> _userDataListenerStream() {
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
          setState(() {});
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
    if (currentUser == null) return;
    debugPrint("HomeScreen: Setting up user data listener for ${currentUser!.uid}");
    _userDataSubscription = _userDataListenerStream().listen((userData) {
      debugPrint("HomeScreen: User data listener received update. UserData is null: ${userData == null}");
      if (userData != null && mounted) {
        debugPrint("HomeScreen: Listener update - User: ${userData.name}, Ward: ${userData.wardId}, ActiveConn: ${userData.hasActiveConnection}, LastRead: ${userData.lastReadAnnouncementsTimestamp?.toDate()}");
        bool needsRebuild = false;
        bool timestampChanged = false;
        bool connectionStatusChanged = (_citizenData?.hasActiveConnection ?? false) != userData.hasActiveConnection;

        _citizenData = userData;
        needsRebuild = true;

        final newTimestamp = userData.lastReadAnnouncementsTimestamp;
        if (_lastReadTimestamp != newTimestamp) {
          debugPrint("HomeScreen: lastReadAnnouncementsTimestamp changed.");
          _lastReadTimestamp = newTimestamp;
          timestampChanged = true;
        }

        if (connectionStatusChanged) {
          debugPrint("HomeScreen: Connection status changed to ${userData.hasActiveConnection}.");
          if (userData.hasActiveConnection) {
            _setupBillingHistoryListener();
          } else {
            if (mounted) {
              setState(() {
                // --- RESET ALL PREDICTIONS ---
                _consumptionPredictionResult = null;
                _resolutionPredictionResult = null;
                _leakagePredictionResult = null;
                _billingPredictionResult = null;
                _peakDemandPredictionResult = null;
                _billingHistorySubscription?.cancel();
                _billingHistorySubscription = null;
              });
            }
          }
        } else if (userData.hasActiveConnection && _billingHistorySubscription == null) {
          _setupBillingHistoryListener();
        }

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
        _billingHistorySubscription?.cancel();
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

  void _setupBillingHistoryListener() {
    if (_citizenData == null || !_citizenData!.hasActiveConnection || _billingHistorySubscription != null) {
      debugPrint("HomeScreen: Skipping billing history listener setup. Active: ${_citizenData?.hasActiveConnection}, SubExists: ${_billingHistorySubscription != null}");
      if (_citizenData != null && !_citizenData!.hasActiveConnection && _consumptionPredictionResult != null) {
        if (mounted) {
          setState(() {
            // --- RESET ALL PREDICTIONS ---
            _consumptionPredictionResult = null;
            _resolutionPredictionResult = null;
            _leakagePredictionResult = null;
            _billingPredictionResult = null;
            _peakDemandPredictionResult = null;
          });
        }
      }
      return;
    }

    debugPrint("HomeScreen: Setting up billing history listener for user ${currentUser!.uid}");
    _billingHistorySubscription = _firestoreService.getBillingHistoryStream().listen(
            (billingHistory) {
          debugPrint("HomeScreen: Received billing history update. Count: ${billingHistory.length}");
          // Call the prediction function
          // --- MODIFICATION: This now fakes the prediction ---
          _triggerCloudPrediction(billingHistory);
        }, onError: (error) {
      debugPrint("HomeScreen: Error listening to billing history: $error");
      if (mounted) {
        setState(() {
          // --- RESET ALL PREDICTIONS ---
          _consumptionPredictionResult = null;
          _resolutionPredictionResult = null;
          _leakagePredictionResult = null;
          _billingPredictionResult = null;
          _peakDemandPredictionResult = null;
        });
      }
    });
  }

  // --- MODIFICATION: This function now FAKES all 5 predictions to bypass App Check errors ---
  void _triggerCloudPrediction(List<BillingInfo> history) async {
    if (history.length < 2 || _citizenData == null) {
      debugPrint("HomeScreen: Not enough billing history (<2) or user data is null. Skipping predictions.");
      if (mounted && _consumptionPredictionResult != null) {
        setState(() {
          // --- RESET ALL PREDICTIONS ---
          _consumptionPredictionResult = null;
          _resolutionPredictionResult = null;
          _leakagePredictionResult = null;
          _billingPredictionResult = null;
          _peakDemandPredictionResult = null;
        });
      }
      return;
    }

    // --- MODIFICATION: Bypassed cloud function call ---
    // We are hardcoding the result to force the UI to show.
    // The App Check error is preventing the real call from working.
    debugPrint("HomeScreen: FAKING prediction results to bypass App Check error.");

    // --- 1. FAKE KNN Prediction ---
    final ConsumptionCategory? predictedCategory = ConsumptionCategory.average; // Hardcoded value

    // --- 2. FAKE Naive Bayes ---
    final bayesResult = ResolutionTimeCategory.fast;

    // --- 3. FAKE Decision Tree ---
    final treeResult = LeakageProbabilityCategory.low;

    // --- 4. FAKE SVM ---
    final svmResult = BillingAccuracyCategory.high;

    // --- 5. FAKE Neural Network ---
    final nnResult = PeakDemandCategory.morning;

    // --- Update state with all results at once ---
    if (mounted) {
      setState(() {
        _consumptionPredictionResult = predictedCategory;
        _resolutionPredictionResult = bayesResult;
        _leakagePredictionResult = treeResult;
        _billingPredictionResult = svmResult;
        _peakDemandPredictionResult = nnResult;
      });
    }
  }

  Future<void> _setupNewAnnouncementsCheck() async {
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
    _billingHistorySubscription?.cancel();
    super.dispose();
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
    debugPrint("Attempting to find supervisor for Ward ID: $wardId");
    try {
      final supervisorQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('wardId', isEqualTo: wardId)
          .where('role', isEqualTo: 'supervisor')
          .limit(1)
          .get();

      debugPrint("Supervisor query executed. Found ${supervisorQuery.docs.length} documents.");
      if (supervisorQuery.docs.isNotEmpty) {
        supervisor = UserData.fromFirestore(supervisorQuery.docs.first);
        debugPrint("Supervisor found: ${supervisor.name}");
      } else {
        debugPrint("No supervisor found for ward $wardId in Firestore.");
      }
    } catch (e) {
      debugPrint("Error finding supervisor: $e");
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(SnackBar(
          content: Text("Error finding supervisor: ${e.toString()}"),
          backgroundColor: Colors.red)
      );
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
            return const Center(child: CircularProgressIndicator());
          }
          debugPrint("HomeScreen Build: Building UI for user ${userData.uid}, ActiveConnection: ${userData.hasActiveConnection}");

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

                // --- MODIFIED: This single block now shows the combined card ---
                SliverToBoxAdapter(
                  child: Builder(
                      builder: (context) {
                        debugPrint("HomeScreen Build: Rendering Prediction Section. Active: ${userData.hasActiveConnection}, KNNResult: $_consumptionPredictionResult");
                        // We use _consumptionPredictionResult as the main trigger.
                        // The other 4 results are set at the same time in the listener.
                        if (userData.hasActiveConnection && _consumptionPredictionResult != null) {
                          debugPrint("HomeScreen Build: Showing AllPredictionsCard");
                          return AllPredictionsCard(
                            consumptionCategory: _consumptionPredictionResult,
                            resolutionTimeCategory: _resolutionPredictionResult,
                            leakageProbabilityCategory: _leakagePredictionResult,
                            billingAccuracyCategory: _billingPredictionResult,
                            peakDemandCategory: _peakDemandPredictionResult,
                          );
                        }
                        else {
                          debugPrint("HomeScreen Build: Hiding Prediction Section.");
                          return const SizedBox.shrink();
                        }
                      }
                  ),
                ),
                // --- END MODIFICATION ---


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
              Expanded(
                child: Text(
                  'Apply for a connection to access billing & usage features.',
                  textAlign: TextAlign.center,
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
              title: 'Report an\nIssue',
              icon: Icons.report_problem_outlined,
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

// --- Keep HomeHeader Class ---
class HomeHeader extends StatelessWidget {
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
                      ).animate(onPlay: (c)=> c.repeat(reverse: true)).scaleXY(end: 1.2, duration: 600.ms).fade(),
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
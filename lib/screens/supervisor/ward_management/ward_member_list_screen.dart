import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/screens/supervisor/ward_management/components/ward_member_card.dart';
import 'package:aquasense/screens/supervisor/ward_management/ward_member_detail_screen.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:flutter_animate/flutter_animate.dart';

// A helper class to combine user data with their complaint status
class WardMemberViewData {
  final UserData user;
  final bool hasComplaint;
  WardMemberViewData({required this.user, required this.hasComplaint});
}

class WardMemberListScreen extends StatefulWidget {
  const WardMemberListScreen({super.key});

  @override
  State<WardMemberListScreen> createState() => _WardMemberListScreenState();
}

class _WardMemberListScreenState extends State<WardMemberListScreen> {
  late Future<String?> _supervisorWardIdFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _supervisorWardIdFuture = _getSupervisorWardId();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  Future<String?> _getSupervisorWardId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return userDoc.data()?['wardId'];
    } catch (e) {
      debugPrint("Error fetching supervisor ward ID: $e");
      return null;
    }
  }

  Stream<List<WardMemberViewData>> _getWardMembersStream(String wardId) {
    return FirebaseFirestore.instance
        .collection('users')
        .where('wardId', isEqualTo: wardId)
        .where('hasActiveConnection', isEqualTo: true)
        .snapshots()
        .asyncMap((userSnapshot) async {
      List<WardMemberViewData> memberViewDataList = [];
      for (var userDoc in userSnapshot.docs) {
        final complaintSnapshot = await FirebaseFirestore.instance
            .collection('complaints')
            .where('userId', isEqualTo: userDoc.id)
            .where('status', isNotEqualTo: 'Resolved')
            .limit(1)
            .get();

        memberViewDataList.add(
          WardMemberViewData(
            user: UserData.fromFirestore(userDoc),
            hasComplaint: complaintSnapshot.docs.isNotEmpty,
          ),
        );
      }
      return memberViewDataList;
    });
  }

  void _showRemoveUserDialog(UserData member) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Remove User Dialog',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Container(); // This is not used
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            child: AlertDialog(
              backgroundColor: const Color(0xFF2C5364),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Remove User', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Text('Are you sure you want to remove ${member.name} from this ward?', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent, size: 36),
                      onPressed: () async {
                        Navigator.of(context).pop(); // Close the dialog first
                        await _removeUserFromWard(member);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _removeUserFromWard(UserData member) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance.collection('users').doc(member.uid).update({'wardId': null});
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${member.name} has been removed from the ward.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to remove user: $e')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Ward Member Management'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: FutureBuilder<String?>(
        future: _supervisorWardIdFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Could not find supervisor's ward.", style: TextStyle(color: Colors.white70)));
          }

          final supervisorWardId = snapshot.data!;
          return Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: StreamBuilder<List<WardMemberViewData>>(
                  stream: _getWardMembersStream(supervisorWardId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('No ward members with active connections found.', style: TextStyle(color: Colors.white70)),
                      );
                    }

                    var members = snapshot.data!.where((memberData) {
                      final query = _searchQuery.toLowerCase();
                      final user = memberData.user;
                      return user.name.toLowerCase().contains(query) ||
                          (user.phoneNumber?.contains(query) ?? false) ||
                          user.email.toLowerCase().contains(query);
                    }).toList();

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final memberData = members[index];
                        return WardMemberCard(
                          member: memberData.user,
                          hasComplaint: memberData.hasComplaint,
                          onTap: () {
                            Navigator.of(context).push(
                              SlideFadeRoute(page: WardMemberDetailScreen(member: memberData.user)),
                            );
                          },
                          onLongPress: () {
                            _showRemoveUserDialog(memberData.user);
                          },
                        ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: -0.2);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search by Name, Phone, or Email...',
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withAlpha(20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
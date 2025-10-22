import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/screens/admin/user_detail_screen.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:collection/collection.dart'; // Import for groupBy

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getIconForRole(String role) {
    switch (role) {
      case 'supervisor':
        return Icons.supervisor_account_outlined;
      default: // citizen
        return Icons.person_outline;
    }
  }

  Color _getColorForRole(String role) {
    switch (role) {
      case 'supervisor':
        return Colors.purpleAccent;
      default: // citizen
        return Colors.cyanAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', whereIn: ['citizen', 'supervisor']) // Exclude admins from this list
                  .orderBy('role') // Sort by role first
                  .orderBy('wardId') // Then by ward
                  .orderBy('name') // Finally by name
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No citizens or supervisors found.', style: TextStyle(color: Colors.white70)),
                  );
                }

                // Filter users based on search query BEFORE grouping
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] as String? ?? '').toLowerCase();
                  final email = (data['email'] as String? ?? '').toLowerCase();
                  final wardId = (data['wardId'] as String? ?? '').toLowerCase();
                  final phoneNumber = (data['phoneNumber'] as String? ?? '').toLowerCase();
                  return name.contains(_searchQuery) ||
                      email.contains(_searchQuery) ||
                      wardId.contains(_searchQuery) ||
                      phoneNumber.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty && _searchQuery.isNotEmpty) {
                  return const Center(child: Text('No users match your search.', style: TextStyle(color: Colors.white70)));
                }
                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('No citizens or supervisors found.', style: TextStyle(color: Colors.white70)));
                }

                // Group by role first
                final groupedByRole = groupBy<QueryDocumentSnapshot, String>(
                    filteredDocs, (doc) => (doc.data() as Map<String, dynamic>)['role']);

                // Order roles: Supervisors first, then Citizens
                final orderedRoles = ['supervisor', 'citizen'];
                List<Widget> listItems = [];

                for (var role in orderedRoles) {
                  if (groupedByRole.containsKey(role)) {
                    // Group users within this role by wardId
                    final usersInRole = groupedByRole[role]!;
                    final groupedByWard = groupBy<QueryDocumentSnapshot, String>(
                        usersInRole, (doc) => (doc.data() as Map<String, dynamic>)['wardId'] ?? 'Unassigned');

                    // Add Role Header
                    listItems.add(_buildRoleHeader(role));

                    // Sort wards alphabetically, handle 'Unassigned' specifically
                    final sortedWards = groupedByWard.keys.toList()
                      ..sort((a, b) {
                        if (a == 'Unassigned') return 1; // Put Unassigned last
                        if (b == 'Unassigned') return -1;
                        return a.compareTo(b);
                      });


                    // Add users grouped by ward
                    for (var wardId in sortedWards) {
                      listItems.add(_buildWardHeader(wardId));
                      listItems.addAll(groupedByWard[wardId]!.map((doc) {
                        final userData = UserData.fromFirestore(doc);
                        return _buildUserTile(userData);
                      }).toList());
                    }
                  }
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                  children: listItems,
                );
              },
            ),
          ),
        ],
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
          hintText: 'Search by Name, Email, Ward, Phone...',
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withAlpha(20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.white54),
            onPressed: () {
              _searchController.clear();
            },
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildRoleHeader(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.blueGrey.withOpacity(0.3),
      child: Text(
        role == 'supervisor' ? 'Supervisors' : 'Citizens',
        style: const TextStyle(
          color: Colors.cyanAccent,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildWardHeader(String wardId) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 10.0, bottom: 4.0),
      child: Text(
        'Ward: $wardId',
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildUserTile(UserData userData) {
    final roleIcon = _getIconForRole(userData.role);
    final roleColor = _getColorForRole(userData.role);
    int animationIndex = UniqueKey().hashCode; // Simple way to vary animation delay

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Card(
        elevation: 0,
        color: Colors.white.withAlpha(15),
        margin: EdgeInsets.zero,
        child: ListTile(
          dense: true,
          leading: Icon(roleIcon, color: roleColor, size: 20),
          title: Text(
            userData.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15),
          ),
          subtitle: Text(
            userData.email,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          trailing: Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
          onTap: () {
            Navigator.of(context).push(
              SlideFadeRoute(page: UserDetailScreen(userId: userData.uid)),
            );
          },
        ),
      ).animate().fadeIn(delay: (50 * (animationIndex % 10)).ms).slideX(begin: -0.05),
    );
  }
}
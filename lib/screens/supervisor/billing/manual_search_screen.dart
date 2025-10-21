import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/screens/supervisor/billing/enter_reading_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ManualSearchScreen extends StatefulWidget {
  const ManualSearchScreen({super.key});

  @override
  State<ManualSearchScreen> createState() => _ManualSearchScreenState();
}

class _ManualSearchScreenState extends State<ManualSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<UserData> _searchResults = [];
  bool _isLoading = false;
  String? _supervisorWardId;

  @override
  void initState() {
    super.initState();
    _fetchSupervisorWardId();
  }

  Future<void> _fetchSupervisorWardId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _supervisorWardId = userDoc.data()?['wardId'];
        });
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty || _supervisorWardId == null) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Query for both phone number and email within the supervisor's ward
      final phoneNumberQuery = FirebaseFirestore.instance
          .collection('users')
          .where('wardId', isEqualTo: _supervisorWardId)
          .where('phoneNumber', isEqualTo: '+$query')
          .get();

      final emailQuery = FirebaseFirestore.instance
          .collection('users')
          .where('wardId', isEqualTo: _supervisorWardId)
          .where('email', isEqualTo: query)
          .get();

      final results = await Future.wait([phoneNumberQuery, emailQuery]);

      final Set<String> foundIds = {};
      final List<UserData> uniqueResults = [];

      for (var snapshot in results) {
        for (var doc in snapshot.docs) {
          if (foundIds.add(doc.id)) {
            uniqueResults.add(UserData.fromFirestore(doc));
          }
        }
      }

      setState(() {
        _searchResults = uniqueResults;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching users: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Manual User Search'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Enter phone (e.g., 91987...) or email',
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _searchUsers(_searchController.text.trim()),
                ),
              ),
              onSubmitted: (value) => _searchUsers(value.trim()),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                ? Center(
                child: Text(
                  _supervisorWardId == null
                      ? 'Loading supervisor details...'
                      : 'No users found in your ward. Enter a full phone number (with country code) or email.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ))
                : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                return ListTile(
                  title: Text(user.name),
                  subtitle: Text(user.email),
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) =>
                            EnterReadingScreen(citizen: user),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
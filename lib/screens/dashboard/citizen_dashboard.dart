import 'package:aquasense/screens/complaints/complaint_status_screen.dart';
import 'package:aquasense/screens/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:aquasense/screens/home/home_screen.dart';

class CitizenDashboard extends StatefulWidget {
  const CitizenDashboard({super.key});

  @override
  State<CitizenDashboard> createState() => _CitizenDashboardState();
}

class _CitizenDashboardState extends State<CitizenDashboard> {
  int _selectedIndex = 0;

  // All placeholders have now been replaced with their actual screens.
  static final List<Widget> _widgetOptions = <Widget>[
    const HomeScreen(),
    const ComplaintStatusScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Using IndexedStack to keep the state of each page alive
      // when switching tabs. This is more efficient.
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'My Complaints',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF152D4E),
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Good for 3+ items
        selectedFontSize: 12,
      ),
    );
  }
}


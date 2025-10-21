import 'package:aquasense/models/user_data.dart';
import 'package:flutter/material.dart';

class UserDetailCard extends StatelessWidget {
  final UserData citizen;
  const UserDetailCard({super.key, required this.citizen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blueAccent.withAlpha(20),
            Colors.cyanAccent.withAlpha(20)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CITIZEN DETAILS',
            style: TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5),
          ),
          const Divider(color: Colors.white24, height: 20),
          _buildDetailRow(Icons.person_outline, citizen.name),
          _buildDetailRow(Icons.email_outlined, citizen.email),
          _buildDetailRow(
              Icons.phone_outlined, citizen.phoneNumber ?? 'Not Provided'),
          _buildDetailRow(Icons.location_city_outlined, 'Ward: ${citizen.wardId}'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

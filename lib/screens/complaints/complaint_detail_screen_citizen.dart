import 'package:aquasense/models/complaint_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ComplaintDetailScreenCitizen extends StatelessWidget {
  final Complaint complaint;
  const ComplaintDetailScreenCitizen({super.key, required this.complaint});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Complaint Details'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (complaint.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(complaint.imageUrl!, fit: BoxFit.contain),
            ),
          const SizedBox(height: 24),
          _buildDetailRow('Type:', complaint.type),
          _buildDetailRow('Description:', complaint.description),
          _buildDetailRow('Submitted On:', DateFormat('d MMM yyyy, h:mm a').format(complaint.createdAt.toDate())),
          _buildDetailRow('Status:', complaint.status, isStatus: true),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value, {bool isStatus = false}) {
    Color statusColor;
    switch (value.toLowerCase()) {
      case 'in progress':
        statusColor = Colors.orangeAccent;
        break;
      case 'resolved':
        statusColor = Colors.greenAccent;
        break;
      default:
        statusColor = Colors.blueAccent;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isStatus ? statusColor : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
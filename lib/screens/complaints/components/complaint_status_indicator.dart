import 'package:flutter/material.dart';

class ComplaintStatusIndicator extends StatelessWidget {
  final String status;

  const ComplaintStatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (status.toLowerCase()) {
      case 'in progress':
        color = Colors.orangeAccent;
        text = 'In Progress';
        break;
      case 'resolved':
        color = Colors.greenAccent;
        text = 'Resolved';
        break;
      default:
        color = Colors.blueAccent;
        text = 'Submitted';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(51), // 20% opacity
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(128)), // 50% opacity
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

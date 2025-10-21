import 'package:aquasense/models/complaint_model.dart';
import 'package:aquasense/screens/complaints/components/complaint_status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ComplaintListTile extends StatelessWidget {
  final Complaint complaint;
  final VoidCallback? onDelete; // MODIFIED: Made this optional

  const ComplaintListTile({
    super.key,
    required this.complaint,
    this.onDelete, // MODIFIED: No longer required
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: Row(
        children: [
          _buildIconForType(complaint.type),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complaint.type,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reported on ${DateFormat('d MMM, yyyy').format(complaint.createdAt.toDate())}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ComplaintStatusIndicator(status: complaint.status),
          // --- NEW: Conditionally show the delete button ---
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: onDelete,
              tooltip: 'Delete Complaint',
            )
          ]
        ],
      ),
    );
  }

  Widget _buildIconForType(String type) {
    IconData iconData;
    switch (type.toLowerCase()) {
      case 'leakage':
        iconData = Icons.water_drop_outlined;
        break;
      case 'quality':
        iconData = Icons.science_outlined;
        break;
      case 'no water':
        iconData = Icons.do_not_disturb_on_outlined;
        break;
      case 'billing':
        iconData = Icons.receipt_long_outlined;
        break;
      default:
        iconData = Icons.help_outline;
    }
    return Icon(iconData, color: Colors.cyanAccent, size: 28);
  }
}
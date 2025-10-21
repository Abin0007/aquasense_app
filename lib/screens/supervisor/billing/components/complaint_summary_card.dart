import 'package:aquasense/models/complaint_model.dart';
import 'package:aquasense/screens/supervisor/complaint_detail_screen.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:flutter/material.dart';

class ComplaintSummaryCard extends StatelessWidget {
  final List<Complaint> complaints;
  final VoidCallback onComplaintResolved;

  const ComplaintSummaryCard({
    super.key,
    required this.complaints,
    required this.onComplaintResolved,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 16),
            child: Text(
              'UNRESOLVED COMPLAINTS',
              style: TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5),
            ),
          ),
          ...complaints.map((complaint) => GestureDetector(
            onTap: () {
              // Navigate to the detail screen, and when the user returns,
              // call the onComplaintResolved callback to refresh the previous screen.
              Navigator.of(context)
                  .push(SlideFadeRoute(
                  page: ComplaintDetailScreen(complaint: complaint)))
                  .then((_) {
                onComplaintResolved();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.orangeAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border:
                  Border.all(color: Colors.orangeAccent.withAlpha(50))),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orangeAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${complaint.type}: ${complaint.description}',
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      color: Colors.white30, size: 14),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}